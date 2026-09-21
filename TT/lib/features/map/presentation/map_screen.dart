import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:turf/turf.dart' as turf;
import '../data/offline_map_service.dart';
import '../data/route_service.dart';
import '../data/location_tracking_service.dart';
import '../data/off_path_calculator.dart';
import '../../test/data/test_expedition.dart';
import '../../test/data/simulation_service.dart';
import '../../emergency/data/emergency_service.dart';
import '../../social/data/deep_link_service.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/socket_service.dart';
import '../../../core/theme/map_marker_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/data/auth_service.dart';
import '../../routes/data/route_recording_service.dart';
import '../../groups/data/group_service.dart';
import '../../mesh/data/mesh_network_service.dart';
import '../data/hotspot_service.dart';
import '../../../core/device_identity.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.expeditionId, this.focusLat, this.focusLng});

  /// Expedition the guide is navigating for. When set, guides may record and
  /// save routes against this expedition.
  final String? expeditionId;

  /// Optional coordinate to center on when opened (e.g. a missing member's
  /// last known location).
  final double? focusLat;
  final double? focusLng;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  // Members may stray this far from the planned route before the expedition
  // tells them to get back on the path. It is the corridor width around the
  // route LineString (a point is "inside" when its distance to the line is
  // within this radius).
  static const double _offPathGraceMeters = 50.0;

  MapLibreMapController? mapController;
  bool _isDownloaded = false;
  String? _regionName;
  LatLng _initialTarget = const LatLng(27.7172, 85.3240); // Default Kathmandu
  bool _isTracking = false;
  bool _isOffPath = false;
  bool _hasCenteredOnUser = false;
  Circle? _userLocationCircle;
  String? _userRole;
  String? _currentUserId;
  bool _isRecording = false;
  LatLng? _currentLocation;
  // Most recent GPS fix, persisted so SOS can still send a location after a
  // restart or while waiting for a fresh fix.
  LatLng? _lastKnownLocation;
  Circle? _startMarkerCircle;
  List<LatLng> _activeRoutePoints = [];

  // Expedition live-tracking state
  final Map<String, Map<String, dynamic>> _roster = {};
  final Map<String, LatLng> _peerLocations = {};
  final Map<String, Circle> _peerMarkers = {};
  // Off-route state per peer, computed with the same calculator the signed-in
  // user's own position uses.
  final Map<String, OffPathResult> _peerOffPath = {};
  // Real-time missing detection driven by peer heartbeats (socket + mesh).
  final Map<String, DateTime> _peerLastSeen = {};
  final Set<String> _missingPeers = {};
  Timer? _missingTimer;
  double _missingThresholdSeconds = 5;
  String? _groupStatus;
  StreamSubscription? _meshTelemetrySub;
  StreamSubscription? _meshHotspotSub;
  StreamSubscription? _locationSub;
  StreamSubscription? _offPathSub;
  bool _offline = false;
  bool _hotspotActive = false;
  Map<String, String> _identity = const {};
  // The expedition being navigated. Comes from the route param, falling back
  // to the active expedition so opening the Map tab keeps its route/context.
  String? _groupId;

  @override
  void initState() {
    super.initState();
    _groupId = widget.expeditionId;
    _loadRegionInfo().then((_) => _loadExpedition());
    _setupLocationListener();
    _setupDeepLinks();
    _setupSocketListeners();
    _setupMeshListeners();
  }

  @override
  void dispose() {
    _missingTimer?.cancel();
    _meshTelemetrySub?.cancel();
    _meshHotspotSub?.cancel();
    _locationSub?.cancel();
    _offPathSub?.cancel();
    ref.read(simulationServiceProvider).stop();
    super.dispose();
  }

  void _setupSocketListeners() {
    final socketSvc = ref.read(socketServiceProvider);
    
    // Listen for peer locations to render them on the map
    socketSvc.peerLocationStream.listen((data) {
      final lat = (data['lat'] as num).toDouble();
      final lng = (data['lng'] as num).toDouble();
      final userId = data['userId'] as String? ?? 'peer';
      _onPeerLocation(userId, LatLng(lat, lng));
    });

    // Listen for new routes (PlanUpdate)
    socketSvc.planUpdateStream.listen((data) {
      // Re-render route based on new GeoJSON
      final routeData = data['route'];
      _renderNewRouteFromSocket(routeData);
    });

    // Listen for emergency distress calls
    socketSvc.emergencyStream.listen((data) {
      final userName = data['userName'] ?? 'Unknown Member';
      final reason = data['reason'] ?? 'Unknown Reason';
      final groupId = (data['groupId'] ?? _groupId)?.toString();
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      _showEmergencyDialog(
        title: 'SOS alert',
        message: '$userName has triggered Rescue Mode.\n\nReason: $reason',
        lat: lat,
        lng: lng,
        groupId: groupId,
        allowResolve: true,
      );
    });

    // Someone resolved the distress call: clear it for everyone.
    socketSvc.emergencyResolvedStream.listen((_) {
      if (mounted) _showSnack('Rescue mode resolved.');
    });

    // SOS from anyone within the alert radius, even outside this expedition.
    socketSvc.nearbyEmergencyStream.listen((data) {
      if (!mounted) return;
      final userName = data['userName'] ?? 'A user';
      final reason = data['reason'] ?? 'Emergency rescue mode activated';
      final distanceKm = (data['distanceKm'] as num?)?.toDouble();
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      final where = distanceKm == null
          ? 'nearby'
          : 'about ${distanceKm.toStringAsFixed(1)} km away';
      _showEmergencyDialog(
        title: 'SOS nearby',
        message: '$userName triggered Rescue Mode $where.\n\nReason: $reason',
        lat: lat,
        lng: lng,
      );
    });

    // Membership/status/route changes: refresh the roster live, and eject if
    // this device is removed from the expedition.
    socketSvc.groupEventStream.listen((data) {
      final event = data['event'];
      if (event == 'group_removed' || event == 'group_deleted') {
        _handleRemovedFromGroup(deleted: event == 'group_deleted');
        return;
      }
      if (_groupId != null && data['groupId']?.toString() == _groupId) {
        _loadExpedition();
      }
    });
  }

  Future<void> _handleRemovedFromGroup({bool deleted = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final groupId = _groupId;
    await prefs.remove('active_group_id');
    if (groupId != null) {
      await prefs.remove('roster_$groupId');
      await prefs.remove('group_status_$groupId');
      await prefs.remove('missing_threshold_$groupId');
      ref.read(socketServiceProvider).leaveGroup(groupId);
    }
    if (!mounted) return;
    _showSnack(
      deleted
          ? 'This expedition was deleted.'
          : 'You were removed from this expedition.',
    );
    context.go('/groups');
  }

  /// Records a peer's position and paints it as a native map marker. Also
  /// refreshes the heartbeat used for real-time missing detection.
  void _onPeerLocation(String userId, LatLng loc) {
    // Ignore live positions unless the expedition is running.
    if (_groupStatus != 'ONGOING') return;
    _peerLocations[userId] = loc;
    _peerLastSeen[userId] = DateTime.now();
    final wasMissing = _missingPeers.remove(userId);
    _renderPeerMarker(userId, loc);
    if (wasMissing) {
      _showSnack('${_peerName(userId)} is back online.');
      if (mounted) setState(() {});
    }
    _checkPeerOffPath(userId);
  }

  /// Runs the shared off-path calculator against a peer's latest fix and, on the
  /// transition to off-route, flags the marker and draws its way back.
  void _checkPeerOffPath(String userId) {
    if (_activeRoutePoints.isEmpty) return;
    if (_roster[userId]?['role'] == 'GUIDE') {
      _peerOffPath.remove(userId);
      return;
    }
    final loc = _peerLocations[userId];
    if (loc == null) return;

    final result = OffPathCalculator.checkOffPath(
      loc,
      _activeRoutePoints,
      _offPathGraceMeters,
    );
    if (result == null) return;

    final wasOff = _peerOffPath[userId]?.isOffPath ?? false;
    _peerOffPath[userId] = result;
    if (result.isOffPath != wasOff) {
      if (result.isOffPath) {
        _showSnack(
          '${_peerName(userId)} is off the route '
          '(${result.distanceMeters.toStringAsFixed(0)} m).',
        );
      }
      _renderPeerMarker(userId, loc);
      if (mounted) setState(() {});
    }
    // Keep the drawn line tracking the peer while it is off the route, and
    // clear it once it rejoins.
    if (result.isOffPath || wasOff) {
      _renderPeerReturnPaths();
    }
  }

  /// Draws a dashed shortest-path line from every off-route peer back to the
  /// nearest point on the route.
  Future<void> _renderPeerReturnPaths() async {
    if (mapController == null) return;

    final features = <Map<String, dynamic>>[];
    for (final entry in _peerOffPath.entries) {
      if (!entry.value.isOffPath) continue;
      final loc = _peerLocations[entry.key];
      if (loc == null) continue;
      final nearest = entry.value.nearestPointOnRoute;
      features.add({
        'type': 'Feature',
        'properties': {'userId': entry.key},
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [loc.longitude, loc.latitude],
            [nearest.longitude, nearest.latitude],
          ],
        },
      });
    }

    try {
      await mapController!.setGeoJsonSource('peer-return-source', {
        'type': 'FeatureCollection',
        'features': features,
      });
    } catch (e) {
      debugPrint('Failed to render peer return paths: $e');
    }
  }

  /// Removes all peer markers and cached positions (e.g. once an expedition is
  /// completed, members must no longer see each other's live locations).
  Future<void> _clearPeers() async {
    _peerLocations.clear();
    _peerLastSeen.clear();
    _missingPeers.clear();
    _peerOffPath.clear();
    if (mapController != null) {
      for (final circle in _peerMarkers.values) {
        try {
          await mapController!.removeCircle(circle);
        } catch (_) {
          // Map may already be disposed; ignore.
        }
      }
    }
    _peerMarkers.clear();
    try {
      await mapController?.setGeoJsonSource('peer-return-source', {
        'type': 'FeatureCollection',
        'features': const [],
      });
    } catch (_) {
      // Map may already be disposed; ignore.
    }
    if (mounted) setState(() {});
  }

  String _peerName(String userId) =>
      _roster[userId]?['name']?.toString() ?? 'A member';

  void _showSnack(String message) {
    if (!mounted) return;
    AppSnackBar.show(context, message);
  }

  /// Member-facing error toast shown when they leave the expedition route
  /// corridor. The red line drawn back to the route is the shortest path to it.
  void _showOffPathToast(double distanceMeters) {
    if (!mounted) return;
    AppSnackBar.showError(
      context,
      'You are ${distanceMeters.toStringAsFixed(0)} m off the route. '
      'Get back on the path shown on the map.',
      duration: const Duration(seconds: 6),
    );
  }

  /// Emergency dialog for an incoming SOS. Deliberately loud, no emoji, one
  /// primary action, with a resolve action for guides.
  void _showEmergencyDialog({
    required String title,
    required String message,
    double? lat,
    double? lng,
    String? groupId,
    bool allowResolve = false,
  }) {
    if (!mounted) return;
    final colors = context.semanticColors;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.sos, size: 36, color: colors.danger),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.danger,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (lat != null && lng != null)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _focusOnSos(lat, lng);
              },
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Go to location'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Dismiss'),
          ),
          if (allowResolve && groupId != null && groupId.isNotEmpty)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.danger,
                foregroundColor: colors.onDanger,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                final done = await ref
                    .read(emergencyServiceProvider)
                    .resolveEmergency(groupId);
                if (!mounted) return;
                if (done) {
                  AppSnackBar.showSuccess(context, 'Rescue mode marked resolved.');
                } else {
                  AppSnackBar.showError(context, 'Could not resolve rescue mode.');
                }
              },
              child: const Text('Mark resolved'),
            ),
        ],
      ),
    );
  }

  /// Watches peer heartbeats and flags anyone quiet for longer than the
  /// configured threshold (5s by default). ONGOING expeditions only.
  void _startMissingWatch() {
    _missingTimer?.cancel();
    if (_groupStatus != 'ONGOING') return;
    _missingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      final threshold =
          Duration(milliseconds: (_missingThresholdSeconds * 1000).round());
      var changed = false;
      for (final entry in _roster.entries) {
        final userId = entry.key;
        if (userId == _currentUserId) continue;
        // The guide is never missing — a quiet guide is just off the path.
        if (entry.value['role'] == 'GUIDE') continue;
        final lastSeen = _peerLastSeen[userId];
        final isMissing = lastSeen == null || now.difference(lastSeen) > threshold;
        if (isMissing && !_missingPeers.contains(userId)) {
          _missingPeers.add(userId);
          final loc = _peerLocations[userId];
          if (loc != null) _renderPeerMarker(userId, loc);
          _showSnack('${_peerName(userId)} is missing.');
          changed = true;
        } else if (!isMissing && _missingPeers.contains(userId)) {
          _missingPeers.remove(userId);
          final loc = _peerLocations[userId];
          if (loc != null) _renderPeerMarker(userId, loc);
          _showSnack('${_peerName(userId)} is back.');
          changed = true;
        }
      }
      if (changed) setState(() {});
    });
  }

  Future<void> _renderPeerMarkers() async {
    if (mapController == null) return;
    for (final entry in _peerLocations.entries) {
      if (entry.key == _currentUserId) continue;
      await _renderPeerMarker(entry.key, entry.value);
    }
  }

  /// Draws (or moves) a peer's marker directly on the map. Peers are never
  /// rendered as floating overlay widgets. Missing peers turn red.
  Future<void> _renderPeerMarker(String userId, LatLng loc) async {
    if (mapController == null || userId == _currentUserId) return;

    final info = _roster[userId];
    final isGuide = info?['role'] == 'GUIDE';
    final isOffPath = _peerOffPath[userId]?.isOffPath ?? false;
    final color = _missingPeers.contains(userId)
        ? MapMarkerColors.missing
        : isOffPath
        ? MapMarkerColors.offRoute
        : (isGuide ? MapMarkerColors.guide : MapMarkerColors.member);

    try {
      final existing = _peerMarkers[userId];
      if (existing == null) {
        _peerMarkers[userId] = await mapController!.addCircle(
          CircleOptions(
            geometry: loc,
            circleRadius: 8.0,
            circleColor: color,
            circleStrokeWidth: 2.0,
            circleStrokeColor: MapMarkerColors.stroke,
          ),
        );
      } else {
        await mapController!.updateCircle(
          existing,
          CircleOptions(geometry: loc, circleColor: color),
        );
      }
    } catch (e) {
      debugPrint('Failed to render peer marker for $userId: $e');
    }
  }

  /// Loads the expedition roster so peers can be labelled and the guide
  /// distinguished, then checks whether we need the offline hotspot.
  Future<void> _loadExpedition() async {
    final prefs = await SharedPreferences.getInstance();

    // Fall back to the last active expedition so the map still shows its route
    // and members when opened directly from the Map tab.
    if (_groupId == null) {
      final active = prefs.getString('active_group_id');
      if (active != null && active.isNotEmpty) _groupId = active;
    }

    final groupId = _groupId;
    if (groupId == null) return;

    // The TEST-Expedition is entirely local: no backend, socket, mesh or GPS.
    if (groupId == TestExpedition.id) {
      await _loadTestExpedition();
      return;
    }

    // Make sure this expedition is the active one for location broadcasts.
    await prefs.setString('active_group_id', groupId);

    // Restore the last-known expedition status/threshold so missing detection
    // keeps working when this device is offline on the mesh.
    _groupStatus = prefs.getString('group_status_$groupId')?.toUpperCase();
    _missingThresholdSeconds =
        prefs.getDouble('missing_threshold_$groupId') ?? 5;

    // Fetch the roster, falling back to a cached copy so labels still work
    // once the device goes offline inside the expedition.
    List<Map<String, dynamic>> members = [];
    try {
      final details =
          await ref.read(groupServiceProvider).getGroupDetails(groupId);
      members = (details?['members'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final status = (details?['group'] as Map?)?['status']?.toString();
      if (status != null) _groupStatus = status.toUpperCase();
      final threshold = details?['missingThresholdSeconds'];
      if (threshold is num && threshold > 0) {
        _missingThresholdSeconds = threshold.toDouble();
      }
      await prefs.setString('group_status_$groupId', _groupStatus ?? '');
      await prefs.setDouble(
          'missing_threshold_$groupId', _missingThresholdSeconds);
      await prefs.setString('roster_$groupId', jsonEncode(members));
    } catch (e) {
      debugPrint('Failed to load expedition roster: $e');
      final cached = prefs.getString('roster_$groupId');
      if (cached != null) {
        members = (jsonDecode(cached) as List).cast<Map<String, dynamic>>();
      }
    }

    var number = 0;
    final ongoing = _groupStatus == 'ONGOING';
    _roster.clear();
    _peerLastSeen.clear();
    _missingPeers.clear();
    for (final member in members) {
      final userId = member['user_id']?.toString() ?? '';
      if (userId.isEmpty) continue;
      final isGuide = member['role']?.toString() == 'GUIDE';
      if (!isGuide) number++;
      _roster[userId] = {
        'name': member['name']?.toString() ?? 'Member',
        'role': member['role']?.toString() ?? 'MEMBER',
        'number': isGuide ? null : number,
        'deviceId': member['device_id']?.toString(),
        'bluetoothName': member['bluetooth_name']?.toString(),
        'isMissing': member['isMissing'] == true,
      };
      // Seed last-known positions so everyone appears immediately, not only
      // after their next live update (only while the expedition runs).
      final lat = member['lat'];
      final lng = member['lng'];
      if (ongoing && userId != _currentUserId && lat is num && lng is num) {
        _peerLocations[userId] = LatLng(lat.toDouble(), lng.toDouble());
      }
      // Seed the heartbeat with the server's last-seen so a member who went
      // quiet before this screen opened is flagged immediately.
      final lastSeenRaw = member['lastSeen'] ?? member['last_seen'];
      if (userId != _currentUserId && lastSeenRaw != null) {
        final parsed = DateTime.tryParse(lastSeenRaw.toString());
        if (parsed != null) _peerLastSeen[userId] = parsed;
      }
    }
    if (mounted) setState(() {});
    if (ongoing) {
      await _renderPeerMarkers();
    } else {
      await _clearPeers();
    }
    _startMissingWatch();

    // Join the expedition room either way so we still receive status changes
    // (and so a completed expedition can be restarted live).
    final socket = ref.read(socketServiceProvider);
    await socket.connect();
    socket.joinGroup(groupId);

    // Live location sharing only happens while the expedition is running.
    if (ongoing && !_isTracking) {
      await _toggleTracking();
    } else if (!ongoing && _isTracking) {
      await _toggleTracking();
    }

    _identity = await ref.read(deviceIdentityProvider).get();
    if (ongoing) {
      _setupExpeditionMesh();
    } else {
      await ref.read(meshNetworkServiceProvider).stopMesh();
    }

    // Draw the expedition's route for both the guide and the members.
    await _renderRoute();

    await _checkConnectivity();
  }

  /// Sets up the local, backend-free TEST-Expedition: a fake roster and route,
  /// then starts the position simulator. No socket, mesh, hotspot or native GPS
  /// is involved — the simulated members arrive through the normal peer stream.
  Future<void> _loadTestExpedition() async {
    _groupStatus = 'ONGOING';
    _missingThresholdSeconds = 30;

    _roster.clear();
    _peerLocations.clear();
    _peerLastSeen.clear();
    _missingPeers.clear();
    _peerOffPath.clear();

    var number = 0;
    for (final actor in TestExpedition.actors) {
      final isGuide = actor.role == 'GUIDE';
      if (!isGuide) number++;
      _roster[actor.userId] = {
        'name': actor.name,
        'role': actor.role,
        'number': isGuide ? null : number,
        'deviceId': null,
        'bluetoothName': null,
        'isMissing': false,
      };
    }

    await _renderRoute();

    if (mounted) setState(() {});
    _startMissingWatch();

    ref.read(simulationServiceProvider).start();
  }

  /// Advertises this device under its own identifier and, if any member is
  /// missing, searches only for that member's Bluetooth identifier/name.
  Future<void> _setupExpeditionMesh() async {
    final mesh = ref.read(meshNetworkServiceProvider);
    await mesh.startAdvertising(_identity['deviceId'] ?? 'traveler');

    final missing = _roster.entries.where((entry) {
      if (entry.key == _currentUserId) return false;
      if (entry.value['isMissing'] != true) return false;
      final id = entry.value['deviceId'] ?? entry.value['bluetoothName'];
      return id != null && id.toString().isNotEmpty;
    }).toList();

    if (missing.isEmpty) {
      await mesh.startDiscovery();
      return;
    }

    final target = (missing.first.value['deviceId'] ??
            missing.first.value['bluetoothName'])
        .toString();
    await mesh.startDiscovery(targetIdentifier: target);
  }

  void _setupMeshListeners() {
    final mesh = ref.read(meshNetworkServiceProvider);
    _meshTelemetrySub = mesh.peerTelemetryStream.listen((data) {
      final lat = data['lat'];
      final lng = data['lng'];
      if (lat is num && lng is num) {
        _onPeerLocation(
          data['userId']?.toString() ?? 'peer',
          LatLng(lat.toDouble(), lng.toDouble()),
        );
      }
    });

    _meshHotspotSub = mesh.hotspotCredentialsStream.listen((data) async {
      if (_groupId != null && data['groupId']?.toString() != _groupId) {
        return;
      }
      final ssid = data['ssid']?.toString();
      final password = data['password']?.toString() ?? '';
      if (ssid == null || ssid.isEmpty) return;
      final connected = await ref
          .read(hotspotServiceProvider)
          .connectToHotspot(ssid, password);
      if (mounted && connected) {
        setState(() => _hotspotActive = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Joined the guide's offline network.")),
        );
      }
    });
  }

  /// If the internet is down for an ongoing expedition, the guide opens a
  /// hotspot and shares its credentials; members join it so live locations
  /// keep flowing over the LAN.
  Future<void> _checkConnectivity() async {
    final groupId = _groupId;
    if (groupId == null || _groupStatus != 'ONGOING') {
      if (mounted) setState(() => _offline = false);
      return;
    }

    final online = await ref.read(hotspotServiceProvider).hasInternet();
    if (mounted) setState(() => _offline = !online);
    if (online) {
      // Back online: flush any routes recorded while offline.
      ref.read(routeRecordingServiceProvider).syncPendingRoutes();
      return;
    }

    final mesh = ref.read(meshNetworkServiceProvider);
    if (_userRole == 'GUIDE') {
      final credentials = await ref.read(hotspotServiceProvider).startHotspot();
      if (credentials == null) return;
      final ssid = credentials['ssid'] ?? '';
      final password = credentials['password'] ?? '';
      if (ssid.isEmpty) return;

      _hotspotActive = true;
      // Best-effort persist for members who regain a connection later.
      await ref
          .read(groupServiceProvider)
          .setHotspot(groupId, ssid: ssid, password: password);
      await mesh.startAdvertising(_identity['deviceId'] ?? 'guide');
      await mesh.broadcastPayload({
        'type': 'hotspot_credentials',
        'groupId': groupId,
        'ssid': ssid,
        'password': password,
      });
      if (mounted) setState(() {});
    } else {
      await mesh.startDiscovery();
    }
  }

  Future<void> _renderNewRouteFromSocket(dynamic routeData) async {
    if (mapController == null || routeData is! Map) return;
    // The socket may deliver a bare LineString geometry; wrap it so MapLibre
    // renders it and off-path detection can use the new points immediately.
    final geoJson = routeData['type'] == 'FeatureCollection'
        ? Map<String, dynamic>.from(routeData)
        : <String, dynamic>{
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'properties': {},
                'geometry': routeData,
              }
            ],
          };
    try {
      await mapController!.setGeoJsonSource("route-source", geoJson);
      // Ensure it's orange as requested for socket updates
      await mapController!.setLayerProperties("route-layer", LineLayerProperties(        lineColor: MapMarkerColors.routeUpdated));
      _activeRoutePoints = RouteService.extractPoints(geoJson);
      ref.read(locationTrackingServiceProvider).setActiveRoute(_activeRoutePoints);
    } catch (e) {
      debugPrint("Failed to render updated route: $e");
    }
  }

  void _setupDeepLinks() {
    final deepLinkSvc = ref.read(deepLinkServiceProvider);
    deepLinkSvc.initDeepLinks();
    deepLinkSvc.uriStream.listen((uri) {
      // Expecting app://location?lat=x&lng=y
      if (uri.scheme == 'app' && uri.host == 'location') {
        final latStr = uri.queryParameters['lat'];
        final lngStr = uri.queryParameters['lng'];
        if (latStr != null && lngStr != null) {
          final lat = double.tryParse(latStr);
          final lng = double.tryParse(lngStr);
          if (lat != null && lng != null) {
            _showSharedLocation(LatLng(lat, lng));
          }
        }
      }
    });
  }

  Future<void> _showSharedLocation(LatLng loc) async {
    if (mapController == null) return;
    await mapController!.addSymbol(
      SymbolOptions(
        geometry: loc,
        iconImage: 'marker-15',
        iconSize: 2.0,
        iconColor: MapMarkerColors.sharedLocation,
      ),
    );
    mapController!.animateCamera(CameraUpdate.newLatLngZoom(loc, 14.0));
  }

  /// Centers the map on a last known location and drops a red marker so the
  /// receiver can act on it.
  Future<void> _focusOnSos(double lat, double lng) async {
    if (mapController == null) return;
    final loc = LatLng(lat, lng);
    try {
      await mapController!.animateCamera(CameraUpdate.newLatLngZoom(loc, 15.0));
      await mapController!.addSymbol(
        SymbolOptions(
          geometry: loc,
          iconImage: 'marker-15',
          iconSize: 2.2,
          iconColor: MapMarkerColors.sos,
        ),
      );
      _showSnack('Centered on last known location.');
    } catch (e) {
      debugPrint('Failed to focus last known location: $e');
    }
  }

  void _setupLocationListener() {
    debugPrint("Setting up UI location listener...");
    _locationSub = ref.read(locationTrackingServiceProvider).locationStream.listen((locationData) {
      final lat = locationData['latitude'] as double;
      final lng = locationData['longitude'] as double;
      final currentLoc = LatLng(lat, lng);

      setState(() {
        _currentLocation = currentLoc;
        _lastKnownLocation = currentLoc;
      });
      // Persist the last known fix so SOS still has a location to send.
      SharedPreferences.getInstance().then((prefs) {
        prefs.setDouble('last_lat', lat);
        prefs.setDouble('last_lng', lng);
      });

      debugPrint("UI received location update: $lat, $lng");

      // Auto-center camera on first GPS fix
      if (!_hasCenteredOnUser && mapController != null) {
        debugPrint("Centering camera on user: $currentLoc");
        mapController!.animateCamera(CameraUpdate.newLatLngZoom(currentLoc, 15.0));
        _hasCenteredOnUser = true;
      }
      
      // Update breadcrumb if recording
      if (_isRecording) {
        _updateRecordingPath();
      }

      // Check off-path (Only if NOT recording and an active route exists)
      if (!_isRecording && _activeRoutePoints.isNotEmpty) {
        final result = OffPathCalculator.checkOffPath(
          currentLoc,
          _activeRoutePoints,
          _offPathGraceMeters,
        );
        
        if (result != null) {
          if (result.isOffPath != _isOffPath) {
              setState(() {
                  _isOffPath = result.isOffPath;
              });
              // The alert itself is raised by LocationTrackingService so it
              // also fires while another tab is visible; here we only keep the
              // marker colour and return line in sync.
          }
          _updateUserMarker(currentLoc, result.isOffPath);
          _drawReturnPath(currentLoc, result.nearestPointOnRoute, result.isOffPath);
        } else {
          _updateUserMarker(currentLoc, false);
        }
      } else {
        // In recording mode or fresh map: skip off-path alerts and ensure return path is hidden
        if (_isOffPath) {
          setState(() => _isOffPath = false);
        }
        _updateUserMarker(currentLoc, false);
        _drawReturnPath(currentLoc, currentLoc, false);
      }

    });

    // Off-route errors are decided by the tracking service (which runs for the
    // whole expedition); surface them here as the member-facing toast.
    _offPathSub = ref.read(locationTrackingServiceProvider).offPathStream.listen((alert) {
      final distance = (alert['distanceMeters'] as num?)?.toDouble() ?? 0;
      _showOffPathToast(distance);
    });
  }

  Future<void> _updateUserMarker(LatLng loc, bool isOffPath) async {
    if (mapController == null) return;
    
    String circleColor = isOffPath
        ? MapMarkerColors.selfOffPath
        : MapMarkerColors.selfOnPath; // Red if off path, blue if on path
    if (_isRecording) {
      circleColor = MapMarkerColors.recordingSelf; // Green while recording
    }

    if (_userLocationCircle == null) {
      _userLocationCircle = await mapController!.addCircle(
        CircleOptions(
          geometry: loc,
          circleRadius: 8.0,
          circleColor: circleColor,
          circleStrokeWidth: 2.0,
          circleStrokeColor: MapMarkerColors.stroke,
        )
      );
    } else {
      await mapController!.updateCircle(
        _userLocationCircle!, 
        CircleOptions(
            geometry: loc,
            circleColor: circleColor,
        )
      );
    }
  }

  Future<void> _drawReturnPath(LatLng current, LatLng nearest, bool isOffPath) async {
    if (mapController == null) return;

    try {
      await mapController!.setLayerVisibility("return-path-layer", isOffPath);
      if (isOffPath) {
        final geoJson = {
          "type": "Feature",
          "properties": {},
          "geometry": {
            "type": "LineString",
            "coordinates": [
              [current.longitude, current.latitude],
              [nearest.longitude, nearest.latitude]
            ]
          }
        };
        await mapController!.setGeoJsonSource("return-path-source", geoJson);
      }
    } catch (e) {
      debugPrint("Error drawing return path: $e");
    }
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await ref.read(locationTrackingServiceProvider).stopTracking();
      setState(() { _isTracking = false; });
    } else {
      // Request permissions first
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.locationAlways, // Added for background service
        Permission.notification,
        // Needed to advertise this device's identity so a missing member can
        // be located by Bluetooth, and to scan for others when we search.
        Permission.bluetoothAdvertise,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      if (statuses[Permission.location]!.isGranted || statuses[Permission.locationAlways]!.isGranted) {
        await ref.read(locationTrackingServiceProvider).startTracking();
        setState(() { _isTracking = true; });
      }
    }
  }

  Future<void> _loadRegionInfo() async {
    final prefs = await SharedPreferences.getInstance();
    _regionName = prefs.getString('destination_name');
    final minLat = prefs.getDouble('min_lat');
    final minLng = prefs.getDouble('min_lng');
    final maxLat = prefs.getDouble('max_lat');
    final maxLng = prefs.getDouble('max_lng');

    if (minLat != null && minLng != null && maxLat != null && maxLng != null) {
      _initialTarget = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    }

    // Restore the last known fix for SOS fallback.
    final lastLat = prefs.getDouble('last_lat');
    final lastLng = prefs.getDouble('last_lng');
    if (lastLat != null && lastLng != null) {
      _lastKnownLocation = LatLng(lastLat, lastLng);
    }

    if (_regionName != null) {
      _isDownloaded = await ref.read(offlineMapServiceProvider).isMapDownloaded(_regionName!);
    }
    
    final profile = await ref.read(authServiceProvider).getProfile();
    _userRole = profile?['user']?['role'] ?? profile?['role']; // Handle different response shapes
    _currentUserId =
        (profile?['user']?['id'] ?? profile?['id'])?.toString();
    ref.read(locationTrackingServiceProvider).setViewerRole(_userRole);

    setState(() {});
  }

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;
  }

  void _onStyleLoaded() {
    _initMapLayers();
  }

  Future<void> _initMapLayers() async {
    if (mapController == null) return;
    final emptyGeoJson = {"type": "FeatureCollection", "features": []};

    try {
      await mapController!.addGeoJsonSource("route-source", emptyGeoJson);
      await mapController!.addLineLayer(
        "route-source",
        "route-layer",
        LineLayerProperties(
          lineColor: MapMarkerColors.sos,
          lineWidth: 4.0,
          lineJoin: "round",
          lineCap: "round",
        ),
      );

      await mapController!.addGeoJsonSource("recording-source", emptyGeoJson);
      await mapController!.addLineLayer(
        "recording-source",
        "recording-layer",
        LineLayerProperties(
          lineColor: MapMarkerColors.recording, // Blue for the path being recorded
          lineWidth: 4.0,
          lineJoin: "round",
          lineCap: "round",
          lineDasharray: [2.0, 2.0],
        ),
      );

      await mapController!.addGeoJsonSource("return-path-source", emptyGeoJson);
      await mapController!.addLineLayer(
        "return-path-source",
        "return-path-layer",
        LineLayerProperties(
          lineColor: MapMarkerColors.sos,
          lineWidth: 3.0,
          lineDasharray: [2.0, 2.0],
        ),
      );
      await mapController!.setLayerVisibility("return-path-layer", false);

      await mapController!.addGeoJsonSource("peer-return-source", emptyGeoJson);
      await mapController!.addLineLayer(
        "peer-return-source",
        "peer-return-layer",
        LineLayerProperties(
          lineColor: MapMarkerColors.offRoute,
          lineWidth: 3.0,
          lineDasharray: [2.0, 2.0],
        ),
      );
    } catch (e) {
      debugPrint("Error initializing map layers: $e");
    }

    await _renderRoute();
    _renderPeerMarkers();

    if (_groupId == TestExpedition.id) {
      await _fitCameraToRoute();
    }

    // When opened via "Go to last known location", center on it.
    final focusLat = widget.focusLat;
    final focusLng = widget.focusLng;
    if (focusLat != null && focusLng != null) {
      _focusOnSos(focusLat, focusLng);
    }
  }

  Future<void> _renderRoute() async {
    if (mapController == null) return;

    // The TEST-Expedition ships its own hardcoded route.
    if (_groupId == TestExpedition.id) {
      final testGeoJson = TestExpedition.routeGeoJson();
      _activeRoutePoints = RouteService.extractPoints(testGeoJson);
      ref
          .read(locationTrackingServiceProvider)
          .setActiveRoute(_activeRoutePoints);
      try {
        await mapController!.setGeoJsonSource("route-source", testGeoJson);
      } catch (e) {
        debugPrint('Error rendering test route: $e');
      }
      return;
    }

    // Prefer the expedition's recorded routes so the guide and every member
    // see the route for the expedition they are navigating.
    Map<String, dynamic>? geoJson;
    final groupId = _groupId;
    if (groupId != null) {
      geoJson =
          await ref.read(routeServiceProvider).getGroupRouteGeoJson(groupId);
    }
    geoJson ??= await ref.read(routeServiceProvider).getGeoJsonRoute();

    // Track points for off-path calculation
    _activeRoutePoints = RouteService.extractPoints(geoJson);
    ref.read(locationTrackingServiceProvider).setActiveRoute(_activeRoutePoints);

    try {
      final data = geoJson ?? {"type": "FeatureCollection", "features": []};
      await mapController!.setGeoJsonSource("route-source", data);
    } catch (e) {
      debugPrint("Error rendering route: $e");
    }
  }

  /// Frames the map on the test route so the whole walk is visible (the test
  /// expedition has no live GPS fix to auto-center on).
  Future<void> _fitCameraToRoute() async {
    if (mapController == null || _activeRoutePoints.isEmpty) return;

    var minLat = _activeRoutePoints.first.latitude;
    var maxLat = minLat;
    var minLng = _activeRoutePoints.first.longitude;
    var maxLng = minLng;
    for (final p in _activeRoutePoints) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }

    try {
      await mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          left: 60,
          top: 120,
          right: 60,
          bottom: 120,
        ),
      );
    } catch (e) {
      debugPrint('Failed to fit camera to test route: $e');
    }
  }

  Future<void> _downloadMap() async {
    if (_regionName == null) return;

    final fileKey = 'maps/${_regionName!.toLowerCase().replaceAll(' ', '_')}.pmtiles';
    
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      await ref.read(offlineMapServiceProvider).downloadRegion(_regionName!, fileKey);
      
      if (mounted) {
        Navigator.pop(context);
        setState(() {
          _isDownloaded = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Map for $_regionName downloaded!')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download map: $e')),
        );
      }
    }
  }

  Future<void> _updateRecordingPath() async {
    if (mapController == null) return;
    
    final points = await ref.read(routeRecordingServiceProvider).getActiveRoutePoints();

    if (points.isEmpty) return;

    final geoJson = {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": {},
          "geometry": {
            "type": "LineString",
            "coordinates": points.map((p) => [p.longitude, p.latitude]).toList(),
          }
        }
      ]
    };

    await mapController!.setGeoJsonSource("recording-source", geoJson);
  }

  void _showStopRecordingDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save Recorded Path'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Trail Name')),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              await ref.read(routeRecordingServiceProvider).stopRecording(
                title: titleController.text,
                description: descController.text,
              );

              // Location must stay ON for a running expedition, so only stop
              // tracking when this recording was standalone (no expedition).
              final inExpedition =
                  _groupId != null && _groupStatus == 'ONGOING';
              if (_isTracking && !inExpedition) {
                await _toggleTracking();
              }

              if (!mounted) return;
              setState(() {
                _isRecording = false;
              });
              navigator.pop();

              // When recording for an expedition, return to it so the newly
              // created route is visible in the expedition's route list.
              final groupId = _groupId;
              if (groupId != null) {
                AppSnackBar.show(context, 'Route saved to expedition.');
                context.go('/expedition/$groupId');
                return;
              }

              AppSnackBar.show(context, 'Path saved and syncing...');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Severity-ordered status stack over the map (missing > off-route > offline).
  /// Returns nothing when all is well so the map stays unobstructed.
  Widget _statusBanners() {
    final banners = <Widget>[];

    final missing = _roster.entries
        .where((e) => _missingPeers.contains(e.key))
        .toList();
    if (missing.isNotEmpty) {
      final labels = missing.map((e) {
        final name = e.value['name']?.toString() ?? 'Member';
        final distance = _distanceLabel(_peerLocations[e.key]);
        return distance == null ? name : '$name ($distance)';
      }).join(', ');
      banners.add(
        AppBanner(
          tone: AppBannerTone.danger,
          iconOverride: Icons.person_search,
          message: 'Missing: $labels',
          onTap: () => context.go('/radar'),
        ),
      );
    }

    final strayed =
        _peerOffPath.entries.where((e) => e.value.isOffPath).toList();
    if (strayed.isNotEmpty) {
      final labels = strayed
          .map((e) =>
              '${_peerName(e.key)} (${e.value.distanceMeters.toStringAsFixed(0)} m)')
          .join(', ');
      banners.add(
        AppBanner(
          tone: AppBannerTone.warning,
          iconOverride: Icons.wrong_location_outlined,
          message: 'Off route: $labels',
        ),
      );
    }

    if (_offline) {
      final message = _hotspotActive
          ? (_userRole == 'GUIDE'
              ? 'Offline: hotspot on. Members can join to share location.'
              : "Offline: connected to the guide's network.")
          : 'Offline: locating peers over the local mesh.';
      banners.add(
        AppBanner(
          tone: AppBannerTone.info,
          iconOverride: _hotspotActive ? Icons.wifi_tethering : Icons.wifi_off,
          message: message,
        ),
      );
    }

    if (banners.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: AppSpacing.md,
      left: AppSpacing.md,
      right: AppSpacing.md,
      child: Column(
        children: [
          for (var i = 0; i < banners.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            banners[i],
          ],
        ],
      ),
    );
  }

  /// Straight-line distance from the current user to a peer's last location.
  String? _distanceLabel(LatLng? loc) {
    final current = _currentLocation;
    if (loc == null || current == null) return null;
    final km = turf.distance(
      turf.Point(
        coordinates: turf.Position(current.longitude, current.latitude),
      ),
      turf.Point(coordinates: turf.Position(loc.longitude, loc.latitude)),
    );
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  /// Sends an SOS for the active expedition using the freshest fix available.
  Future<void> _triggerRescue() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final groupId = prefs.getString('active_group_id') ?? '';
    if (groupId.isEmpty) {
      AppSnackBar.showError(context, 'No active expedition selected.');
      return;
    }
    // Freshest fix, else the last known location before signal was lost, else
    // the map target as a last resort.
    final loc = _currentLocation ?? _lastKnownLocation;
    if (loc == null) {
      _showSnack('No location known yet — sending map center.');
    }
    await ref.read(emergencyServiceProvider).triggerRescueMode(
          groupId,
          loc?.latitude ?? _initialTarget.latitude,
          loc?.longitude ?? _initialTarget.longitude,
          null,
          'User triggered rescue mode.',
        );
    if (!mounted) return;
    AppSnackBar.showSuccess(context, 'Rescue mode activated.');
  }

  /// Starts or stops guide route recording, preserving the yellow start marker.
  Future<void> _onRecordPressed() async {
    if (_isRecording) {
      _showStopRecordingDialog();
      if (_startMarkerCircle != null) {
        await mapController!.removeCircle(_startMarkerCircle!);
        _startMarkerCircle = null;
      }
      return;
    }

    // Ensure tracking is ON before recording.
    if (!_isTracking) {
      await _toggleTracking();
    }

    await ref.read(routeRecordingServiceProvider).startRecording(
          initialLat: _currentLocation?.latitude,
          initialLng: _currentLocation?.longitude,
          groupId: _groupId,
        );

    if (_currentLocation != null && mapController != null) {
      _startMarkerCircle = await mapController!.addCircle(
        CircleOptions(
          geometry: _currentLocation!,
          circleRadius: 6.0,
          circleColor: MapMarkerColors.start,
          circleStrokeWidth: 2.0,
          circleStrokeColor: MapMarkerColors.startStroke,
        ),
      );
    }

    setState(() {
      _isRecording = true;
      _isOffPath = false;
    });

    if (mapController != null) {
      await mapController!.setLayerVisibility('return-path-layer', false);
    }

    if (!mounted) return;
    AppSnackBar.show(context, 'Started recording trail...');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Scaffold(
      appBar: AppBar(
        title: Text(_regionName ?? 'Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.radar),
            onPressed: () => context.push('/radar'),
            tooltip: 'Find missing people',
          ),
          if (!_isDownloaded && _regionName != null)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadMap,
              tooltip: 'Download offline map',
            )
          else if (_isDownloaded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Icon(Icons.offline_pin, color: colors.success),
            ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: Stack(
        children: [
          MapLibreMap(
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            initialCameraPosition: CameraPosition(
              target: _initialTarget,
              zoom: 12.0,
            ),
            styleString: MapLibreStyles.openfreemapLiberty,
          ),
          _statusBanners(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_userRole == 'GUIDE' &&
                  (_groupId != null || _isRecording)) ...[
                FloatingActionButton.small(
                  heroTag: 'recordBtn',
                  onPressed: _onRecordPressed,
                  tooltip: _isRecording ? 'Save trail' : 'Record trail',
                  backgroundColor:
                      _isRecording ? colors.danger : colors.surfaceElevated,
                  foregroundColor:
                      _isRecording ? colors.onDanger : colors.primaryText,
                  child: Icon(
                    _isRecording ? Icons.save : Icons.fiber_manual_record,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              FloatingActionButton.small(
                heroTag: 'trackBtn',
                onPressed: _toggleTracking,
                tooltip: _isTracking ? 'Stop tracking' : 'Start tracking',
                backgroundColor:
                    _isTracking ? colors.danger : colors.surfaceElevated,
                foregroundColor:
                    _isTracking ? colors.onDanger : colors.primaryText,
                child: Icon(_isTracking ? Icons.stop : Icons.navigation),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: 220,
            child: HoldToConfirmButton(
              label: 'Hold for SOS',
              holdLabel: 'Keep holding…',
              icon: Icons.sos,
              onConfirmed: _triggerRescue,
            ),
          ),
        ],
      ),
    );
  }
}

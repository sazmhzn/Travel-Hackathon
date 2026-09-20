import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import '../data/offline_map_service.dart';
import '../data/route_service.dart';
import '../data/location_tracking_service.dart';
import '../data/off_path_calculator.dart';
import '../../emergency/data/emergency_service.dart';
import '../../social/data/deep_link_service.dart';
import '../../../core/socket_service.dart';
import '../../auth/data/auth_service.dart';
import '../../routes/data/route_recording_service.dart';
import '../../groups/data/group_service.dart';
import '../../mesh/data/mesh_network_service.dart';
import '../data/hotspot_service.dart';
import '../../../core/device_identity.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.expeditionId});

  /// Expedition the guide is navigating for. When set, guides may record and
  /// save routes against this expedition.
  final String? expeditionId;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
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
  Circle? _startMarkerCircle;
  List<LatLng> _activeRoutePoints = [];

  // Expedition live-tracking state
  final Map<String, Map<String, dynamic>> _roster = {};
  final Map<String, LatLng> _peerLocations = {};
  final Map<String, Offset> _peerScreenPositions = {};
  StreamSubscription? _meshTelemetrySub;
  StreamSubscription? _meshHotspotSub;
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
    _meshTelemetrySub?.cancel();
    _meshHotspotSub?.cancel();
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
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('🚨 SOS Alert!', style: TextStyle(color: Colors.red)),
            content: Text('$userName has triggered Rescue Mode.\n\nReason: $reason'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Understood'),
              )
            ],
          )
        );
      }
    });
  }

  /// Records a peer's position and repaints the Flutter overlay badges.
  void _onPeerLocation(String userId, LatLng loc) {
    _peerLocations[userId] = loc;
    _refreshPeerScreenPositions();
    if (mounted) setState(() {});
  }

  Future<void> _refreshPeerScreenPositions() async {
    if (mapController == null) return;
    for (final entry in _peerLocations.entries) {
      try {
        final screen = await mapController!.toScreenLocation(entry.value);
        _peerScreenPositions[entry.key] = Offset(
          screen.x.toDouble(),
          screen.y.toDouble(),
        );
      } catch (_) {
        // Map not ready yet; skip this frame.
      }
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

    // Make sure this expedition is the active one for location broadcasts.
    await prefs.setString('active_group_id', groupId);

    // Fetch the roster, falling back to a cached copy so labels still work
    // once the device goes offline inside the expedition.
    List<Map<String, dynamic>> members = [];
    try {
      final details =
          await ref.read(groupServiceProvider).getGroupDetails(groupId);
      members = (details?['members'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      await prefs.setString('roster_$groupId', jsonEncode(members));
    } catch (e) {
      print('Failed to load expedition roster: $e');
      final cached = prefs.getString('roster_$groupId');
      if (cached != null) {
        members = (jsonDecode(cached) as List).cast<Map<String, dynamic>>();
      }
    }

    var number = 0;
    _roster.clear();
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
      // after their next live update.
      final lat = member['lat'];
      final lng = member['lng'];
      if (userId != _currentUserId && lat is num && lng is num) {
        _peerLocations[userId] = LatLng(lat.toDouble(), lng.toDouble());
      }
    }
    if (mounted) setState(() {});
    await _refreshPeerScreenPositions();

    // Join the expedition room and start broadcasting our position so every
    // member's live location shows up on the map.
    final socket = ref.read(socketServiceProvider);
    await socket.connect();
    socket.joinGroup(groupId);
    if (!_isTracking) {
      await _toggleTracking();
    }

    _identity = await ref.read(deviceIdentityProvider).get();
    _setupExpeditionMesh();

    // Draw the expedition's route for both the guide and the members.
    await _renderRoute();

    await _checkConnectivity();
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
    if (groupId == null) {
      if (mounted) setState(() => _offline = false);
      return;
    }

    final online = await ref.read(hotspotServiceProvider).hasInternet();
    if (mounted) setState(() => _offline = !online);
    if (online) return;

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

  Future<void> _renderNewRouteFromSocket(Map<String, dynamic> geoJson) async {
    if (mapController == null) return;
    try {
      await mapController!.setGeoJsonSource("route-source", geoJson);
      // Ensure it's orange as requested for socket updates
      await mapController!.setLayerProperties("route-layer", LineLayerProperties(lineColor: "#FF8C00"));
    } catch (e) {
      print("Failed to render updated route: $e");
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
        iconColor: '#FF00FF',
      )
    );
    mapController!.animateCamera(CameraUpdate.newLatLngZoom(loc, 14.0));
  }

  void _setupLocationListener() {
    print("Setting up UI location listener...");
    ref.read(locationTrackingServiceProvider).locationStream.listen((locationData) {
      final lat = locationData['latitude'] as double;
      final lng = locationData['longitude'] as double;
      final currentLoc = LatLng(lat, lng);
      
      setState(() {
        _currentLocation = currentLoc;
      });

      print("UI received location update: $lat, $lng");

      // Auto-center camera on first GPS fix
      if (!_hasCenteredOnUser && mapController != null) {
        print("Centering camera on user: $currentLoc");
        mapController!.animateCamera(CameraUpdate.newLatLngZoom(currentLoc, 15.0));
        _hasCenteredOnUser = true;
      }
      
      // Update breadcrumb if recording
      if (_isRecording) {
        _updateRecordingPath();
      }

      // Check off-path (Only if NOT recording and an active route exists)
      if (!_isRecording && _activeRoutePoints.isNotEmpty) {
        final result = OffPathCalculator.checkOffPath(currentLoc, _activeRoutePoints, 50.0);
        
        if (result != null) {
          if (result.isOffPath != _isOffPath) {
              setState(() {
                  _isOffPath = result.isOffPath;
              });
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
  }

  Future<void> _updateUserMarker(LatLng loc, bool isOffPath) async {
    if (mapController == null) return;
    
    String circleColor = isOffPath ? '#FF0000' : '#0000FF'; // Red if off path, Blue if on path
    if (_isRecording) {
      circleColor = '#00FF00'; // Green while recording
    }

    if (_userLocationCircle == null) {
      _userLocationCircle = await mapController!.addCircle(
        CircleOptions(
          geometry: loc,
          circleRadius: 8.0,
          circleColor: circleColor,
          circleStrokeWidth: 2.0,
          circleStrokeColor: '#FFFFFF',
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
      print("Error drawing return path: $e");
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

    if (_regionName != null) {
      _isDownloaded = await ref.read(offlineMapServiceProvider).isMapDownloaded(_regionName!);
    }
    
    final profile = await ref.read(authServiceProvider).getProfile();
    _userRole = profile?['user']?['role'] ?? profile?['role']; // Handle different response shapes
    _currentUserId =
        (profile?['user']?['id'] ?? profile?['id'])?.toString();

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
          lineColor: "#FF0000",
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
          lineColor: "#0000FF", // Blue for the path being recorded
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
          lineColor: "#FF0000",
          lineWidth: 3.0,
          lineDasharray: [2.0, 2.0],
        ),
      );
      await mapController!.setLayerVisibility("return-path-layer", false);
    } catch (e) {
      print("Error initializing map layers: $e");
    }

    _renderRoute();
  }

  Future<void> _renderRoute() async {
    if (mapController == null) return;

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

    try {
      final data = geoJson ?? {"type": "FeatureCollection", "features": []};
      await mapController!.setGeoJsonSource("route-source", data);
    } catch (e) {
      print("Error rendering route: $e");
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
              await ref.read(routeRecordingServiceProvider).stopRecording(
                title: titleController.text,
                description: descController.text,
              );

              // Also stop the underlying location tracking service to save battery
              if (_isTracking) {
                await _toggleTracking();
              }

              setState(() {
                _isRecording = false;
              });
              Navigator.pop(dialogContext);

              // When recording for an expedition, return to it so the newly
              // created route is visible in the expedition's route list.
              final groupId = _groupId;
              if (groupId != null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Route saved to expedition.')),
                  );
                  context.go('/expedition/$groupId');
                }
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Path saved and syncing...')));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPeerBadges() {
    final badges = <Widget>[];
    _peerScreenPositions.forEach((userId, position) {
      final info = _roster[userId];
      final isGuide = info?['role'] == 'GUIDE';
      final isSelf = userId == _currentUserId;
      final label = isGuide ? 'G' : '${info?['number'] ?? '?'}';
      final color = isGuide ? const Color(0xFF1D4ED8) : const Color(0xFFEC4899);
      badges.add(
        Positioned(
          left: position.dx - 16,
          top: position.dy - 16,
          child: IgnorePointer(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelf ? Colors.white : Colors.white70,
                  width: isSelf ? 3 : 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      );
    });
    return badges;
  }

  Widget _offlineBanner() {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                _hotspotActive ? Icons.wifi_tethering : Icons.wifi_off,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _hotspotActive
                      ? (_userRole == 'GUIDE'
                          ? 'Offline: hotspot on. Members can join to share location.'
                          : "Offline: connected to the guide's network.")
                      : 'Offline: locating peers over the local mesh.',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_regionName ?? 'Travel Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.radar),
            onPressed: () => context.push('/radar'),
            tooltip: 'Proximity Radar',
          ),
          if (!_isDownloaded && _regionName != null)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadMap,
              tooltip: 'Download Offline Map',
            )
          else if (_isDownloaded)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Icon(Icons.offline_pin, color: Colors.green),
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
            onCameraIdle: _refreshPeerScreenPositions,
            onCameraMove: (_) => _refreshPeerScreenPositions(),
            initialCameraPosition: CameraPosition(
              target: _initialTarget,
              zoom: 12.0,
            ),
            styleString: MapLibreStyles.openfreemapLiberty,
          ),
          ..._buildPeerBadges(),
          if (_offline) _offlineBanner(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'rescueBtn',
            onPressed: () async {
              final emergencySvc = ref.read(emergencyServiceProvider);
              final prefs = await SharedPreferences.getInstance();
              final groupId = prefs.getString('active_group_id') ?? '';
              
              if (groupId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error: No active group selected.'))
                );
                return;
              }

              // Trigger emergency with real groupId
              await emergencySvc.triggerRescueMode(
                groupId, 
                _initialTarget.latitude, 
                _initialTarget.longitude, 
                15, 
                "User triggered rescue mode."
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rescue Mode Activated!'))
                );
              }
            },
            backgroundColor: Colors.orange,
            child: const Icon(Icons.warning),
          ),
          const SizedBox(height: 16),
          if (_userRole == 'GUIDE' && (_groupId != null || _isRecording))
            FloatingActionButton(
              heroTag: 'recordBtn',
              onPressed: () async {
                if (_isRecording) {
                  _showStopRecordingDialog();
                  if (_startMarkerCircle != null) {
                    await mapController!.removeCircle(_startMarkerCircle!);
                    _startMarkerCircle = null;
                  }
                } else {
                  // Ensure tracking is ON
                  if (!_isTracking) {
                    await _toggleTracking();
                  }
                  
                  // Start recording with current location if available
                  await ref.read(routeRecordingServiceProvider).startRecording(
                    initialLat: _currentLocation?.latitude,
                    initialLng: _currentLocation?.longitude,
                    groupId: _groupId,
                  );

                  // Add a "Start" marker at current position
                  if (_currentLocation != null && mapController != null) {
                    _startMarkerCircle = await mapController!.addCircle(
                      CircleOptions(
                        geometry: _currentLocation!,
                        circleRadius: 6.0,
                        circleColor: '#FFFF00', // Yellow start point
                        circleStrokeWidth: 2.0,
                        circleStrokeColor: '#000000',
                      )
                    );
                  }

                  setState(() {
                    _isRecording = true;
                    _isOffPath = false; // Reset off-path state
                  });
                  
                  // Explicitly hide return path if it was showing
                  if (mapController != null) {
                    await mapController!.setLayerVisibility("return-path-layer", false);
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Started recording trail...')));
                }
              },
              backgroundColor: _isRecording ? Colors.green : Colors.grey,
              child: Icon(_isRecording ? Icons.save : Icons.fiber_manual_record),
            ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'trackBtn',
            onPressed: _toggleTracking,
            backgroundColor: _isTracking ? Colors.red : Colors.blue,
            child: Icon(_isTracking ? Icons.stop : Icons.navigation),
          ),
        ],
      ),
    );
  }
}

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

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _loadRegionInfo();
    _setupLocationListener();
    _setupDeepLinks();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    final socketSvc = ref.read(socketServiceProvider);
    
    // Listen for peer locations to render them on the map
    socketSvc.peerLocationStream.listen((data) {
      final lat = data['lat'] as double;
      final lng = data['lng'] as double;
      final userId = data['userId'] as String? ?? 'peer';
      _updatePeerMarker(userId, LatLng(lat, lng));
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

  final Map<String, Circle> _peerMarkers = {};

  Future<void> _updatePeerMarker(String userId, LatLng loc) async {
    if (mapController == null) return;
    
    if (_peerMarkers.containsKey(userId)) {
      await mapController!.updateCircle(
        _peerMarkers[userId]!,
        CircleOptions(geometry: loc)
      );
    } else {
      final circle = await mapController!.addCircle(
        CircleOptions(
          geometry: loc,
          circleRadius: 6.0,
          circleColor: '#00FF00', // green for peers
          circleStrokeWidth: 1.5,
          circleStrokeColor: '#FFFFFF',
        )
      );
      _peerMarkers[userId] = circle;
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
    ref.read(locationTrackingServiceProvider).locationStream.listen((locationData) {
      final lat = locationData['latitude'] as double;
      final lng = locationData['longitude'] as double;
      final currentLoc = LatLng(lat, lng);
      
      // Auto-center camera on first GPS fix
      if (!_hasCenteredOnUser && mapController != null) {
        mapController!.animateCamera(CameraUpdate.newLatLngZoom(currentLoc, 15.0));
        _hasCenteredOnUser = true;
      }
      
      // Check off-path
      final route = ref.read(routeServiceProvider).getMockRoute();
      final result = OffPathCalculator.checkOffPath(currentLoc, route, 50.0);
      
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

    });
  }

  Future<void> _updateUserMarker(LatLng loc, bool isOffPath) async {
    if (mapController == null) return;
    
    final circleColor = isOffPath ? '#FF0000' : '#0000FF'; // Red if off path, Blue if on path

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
        Permission.notification,
      ].request();

      if (statuses[Permission.location]!.isGranted) {
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
    final geoJson = await ref.read(routeServiceProvider).getGeoJsonRoute();
    try {
      await mapController!.setGeoJsonSource("route-source", geoJson);
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
      body: MapLibreMap(
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        initialCameraPosition: CameraPosition(
          target: _initialTarget,
          zoom: 12.0,
        ),
        styleString: MapLibreStyles.openfreemapLiberty,
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

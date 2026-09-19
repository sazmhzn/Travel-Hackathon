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

import '../../../core/database_provider.dart';
import '../../routes/data/models/draft_route.dart';
import '../../routes/data/models/route_point.dart';
// Note: Manually importing generated files sometimes fixes member-lookup issues in some IDE/Compiler versions
// but part files cannot be imported. They should be available via the main file.
import '../../auth/data/auth_service.dart';
import '../../routes/data/route_recording_service.dart';

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
  String? _userRole;
  bool _isRecording = false;
  LatLng? _currentLocation;
  Circle? _startMarkerCircle;
  List<LatLng> _activeRoutePoints = [];

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
    final geoJson = await ref.read(routeServiceProvider).getGeoJsonRoute();
    
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
      builder: (context) => AlertDialog(
        title: const Text('Save Recorded Path'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Trail Name')),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Path saved and syncing...')));
            },
            child: const Text('Save'),
          ),
        ],
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
          if (_userRole == 'GUIDE')
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

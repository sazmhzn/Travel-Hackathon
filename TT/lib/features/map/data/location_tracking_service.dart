import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/socket_service.dart';
import 'off_path_calculator.dart';

final locationTrackingServiceProvider = Provider((ref) => LocationTrackingService(ref));

class LocationTrackingService {
  final Ref _ref;
  static const MethodChannel _methodChannel = MethodChannel('com.example.tt/location_control');
  static const EventChannel _eventChannel = EventChannel('com.example.tt/location_updates');

  // A member may stray this far from the route before being told to get back.
  // This is the corridor width around the route LineString.
  static const double offPathGraceMeters = 50.0;

  StreamSubscription? _locationSubscription;

  final StreamController<Map<String, dynamic>> _locationStreamController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get locationStream => _locationStreamController.stream;

  // Fires once each time the member crosses from on-route to off-route while an
  // expedition is running, so any screen can surface the error.
  final StreamController<Map<String, dynamic>> _offPathController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get offPathStream => _offPathController.stream;

  List<LatLng> _activeRoute = const [];
  String? _viewerRole;
  bool _wasOffPath = false;

  bool get isTracking => _locationSubscription != null;

  LocationTrackingService(this._ref);

  /// The route to stay within, shared by every screen. Set whenever the
  /// expedition route is (re)loaded so detection keeps working off the Map tab.
  void setActiveRoute(List<LatLng> points) {
    _activeRoute = List.unmodifiable(points);
    _wasOffPath = false;
  }

  /// Members are alerted when they leave the route; guides are not.
  void setViewerRole(String? role) {
    _viewerRole = role;
  }

  Future<void> startTracking() async {
    if (isTracking) return;
    try {
      // Start listening BEFORE invoking the method to ensure no initial updates are missed
      _startListeningToUpdates();

      final bool started = await _methodChannel.invokeMethod('startTracking');
      if (started) {
        debugPrint("Native location tracking service started successfully.");
        // Also connect to Socket.IO when tracking starts
        await _ref.read(socketServiceProvider).connect();
      } else {
        _stopListeningToUpdates();
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to start tracking: '${e.message}'.");
      _stopListeningToUpdates();
    }
  }

  Future<void> stopTracking() async {
    try {
      await _methodChannel.invokeMethod('stopTracking');
      _stopListeningToUpdates();
    } on PlatformException catch (e) {
      debugPrint("Failed to stop tracking: '${e.message}'.");
    }
  }

  void _startListeningToUpdates() {
    if (_locationSubscription != null) return;

    debugPrint("Subscribing to native location update stream...");
    _locationSubscription = _eventChannel.receiveBroadcastStream().listen((dynamic event) async {
      final locationData = Map<String, dynamic>.from(event);
      debugPrint("Received location from native: Lat: ${locationData['latitude']}, Lng: ${locationData['longitude']}, Acc: ${locationData['accuracy']}");
      _locationStreamController.add(locationData);

      // Emit to WebSocket only while part of a running expedition. If we were
      // removed, the expedition finished, or none is active there is nothing
      // meaningful to broadcast (and no reason to spend bandwidth/redraw peers).
      final prefs = await SharedPreferences.getInstance();
      final groupId = prefs.getString('active_group_id');
      if (groupId == null || groupId.isEmpty) return;

      final status = prefs.getString('group_status_$groupId')?.toUpperCase();
      if (status != 'ONGOING') {
        _wasOffPath = false;
        return;
      }

      _ref.read(socketServiceProvider).emitLocationUpdate(
        groupId,
        locationData['latitude'] as double,
        locationData['longitude'] as double,
        0.0, // Altitude mock
        0.0, // Speed mock
        100 // Battery mock
      );

      _checkOffPath(locationData);
    }, onError: (dynamic error) {
      debugPrint('Received error: ${error.message}');
    });
  }

  /// Route-corridor check for members. Runs on every live fix, including while
  /// the Map is not the visible tab, and notifies only on the on-route →
  /// off-route transition so the member is not spammed.
  void _checkOffPath(Map<String, dynamic> locationData) {
    if (_activeRoute.length < 2) return;
    if (_viewerRole != 'MEMBER') return;

    final lat = (locationData['latitude'] as num?)?.toDouble();
    final lng = (locationData['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    final result = OffPathCalculator.checkOffPath(
      LatLng(lat, lng),
      _activeRoute,
      offPathGraceMeters,
    );
    if (result == null) return;

    if (result.isOffPath && !_wasOffPath) {
      OffPathCalculator.triggerAlert(result.distanceMeters);
      _offPathController.add({
        'distanceMeters': result.distanceMeters,
        'nearestLat': result.nearestPointOnRoute.latitude,
        'nearestLng': result.nearestPointOnRoute.longitude,
      });
    }
    _wasOffPath = result.isOffPath;
  }

  void _stopListeningToUpdates() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  void dispose() {
    _stopListeningToUpdates();
    _locationStreamController.close();
    _offPathController.close();
  }
}

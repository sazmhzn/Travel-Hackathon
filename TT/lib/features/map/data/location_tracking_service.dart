import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/socket_service.dart';

final locationTrackingServiceProvider = Provider((ref) => LocationTrackingService(ref));

class LocationTrackingService {
  final Ref _ref;
  static const MethodChannel _methodChannel = MethodChannel('com.example.tt/location_control');
  static const EventChannel _eventChannel = EventChannel('com.example.tt/location_updates');

  StreamSubscription? _locationSubscription;
  
  final StreamController<Map<String, dynamic>> _locationStreamController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get locationStream => _locationStreamController.stream;

  LocationTrackingService(this._ref);

  Future<void> startTracking() async {
    try {
      // Start listening BEFORE invoking the method to ensure no initial updates are missed
      _startListeningToUpdates();

      final bool started = await _methodChannel.invokeMethod('startTracking');
      if (started) {
        print("Native location tracking service started successfully.");
        // Also connect to Socket.IO when tracking starts
        await _ref.read(socketServiceProvider).connect();
      } else {
        _stopListeningToUpdates();
      }
    } on PlatformException catch (e) {
      print("Failed to start tracking: '${e.message}'.");
      _stopListeningToUpdates();
    }
  }

  Future<void> stopTracking() async {
    try {
      await _methodChannel.invokeMethod('stopTracking');
      _stopListeningToUpdates();
    } on PlatformException catch (e) {
      print("Failed to stop tracking: '${e.message}'.");
    }
  }

  void _startListeningToUpdates() {
    if (_locationSubscription != null) return;

    print("Subscribing to native location update stream...");
    _locationSubscription = _eventChannel.receiveBroadcastStream().listen((dynamic event) async {
      final locationData = Map<String, dynamic>.from(event);
      print("Received location from native: Lat: ${locationData['latitude']}, Lng: ${locationData['longitude']}, Acc: ${locationData['accuracy']}");
      _locationStreamController.add(locationData);

      // Emit to WebSocket only while part of an expedition. If we were removed
      // (or none is active) there is nothing meaningful to broadcast.
      final prefs = await SharedPreferences.getInstance();
      final groupId = prefs.getString('active_group_id');
      if (groupId == null || groupId.isEmpty) return;

      _ref.read(socketServiceProvider).emitLocationUpdate(
        groupId,
        locationData['latitude'] as double,
        locationData['longitude'] as double,
        0.0, // Altitude mock
        0.0, // Speed mock
        100 // Battery mock
      );
    }, onError: (dynamic error) {
      print('Received error: ${error.message}');
    });
  }

  void _stopListeningToUpdates() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  void dispose() {
    _stopListeningToUpdates();
    _locationStreamController.close();
  }
}

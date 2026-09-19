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
      final bool started = await _methodChannel.invokeMethod('startTracking');
      if (started) {
        _startListeningToUpdates();
        // Also connect to Socket.IO when tracking starts
        await _ref.read(socketServiceProvider).connect();
      }
    } on PlatformException catch (e) {
      print("Failed to start tracking: '${e.message}'.");
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
    _locationSubscription = _eventChannel.receiveBroadcastStream().listen((dynamic event) async {
      final locationData = Map<String, dynamic>.from(event);
      _locationStreamController.add(locationData);

      // Emit to WebSocket
      final prefs = await SharedPreferences.getInstance();
      final groupId = prefs.getString('destination_name') ?? 'group123'; // Mock group id fallback

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

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'offline_telemetry_record.dart';
import 'sync_manager.dart';

final meshNetworkServiceProvider = Provider((ref) => MeshNetworkService(ref));

class MeshNetworkService {
  final Ref _ref;
  static const MethodChannel _methodChannel = MethodChannel(
    'com.example.tt/mesh_control',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.example.tt/mesh_updates',
  );

  StreamSubscription? _meshSubscription;

  final _peerTelemetryController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _hotspotCredentialsController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Live telemetry received directly from peers over the P2P mesh (works
  /// without internet or a backend).
  Stream<Map<String, dynamic>> get peerTelemetryStream =>
      _peerTelemetryController.stream;

  /// Hotspot credentials broadcast by the guide when the internet drops.
  Stream<Map<String, dynamic>> get hotspotCredentialsStream =>
      _hotspotCredentialsController.stream;

  MeshNetworkService(this._ref);

  Future<void> startAdvertising(String userId) async {
    try {
      await _methodChannel.invokeMethod('startAdvertising', {'userId': userId});
      _startListeningForPayloads();
    } on PlatformException catch (e) {
      print("Failed to start mesh advertising: '${e.message}'.");
    }
  }

  Future<void> startDiscovery() async {
    try {
      await _methodChannel.invokeMethod('startDiscovery');
      _startListeningForPayloads();
    } on PlatformException catch (e) {
      print("Failed to start mesh discovery: '${e.message}'.");
    }
  }

  Future<void> stopMesh() async {
    try {
      await _methodChannel.invokeMethod('stopMesh');
      _stopListeningForPayloads();
    } on PlatformException catch (e) {
      print("Failed to stop mesh: '${e.message}'.");
    }
  }

  Future<void> broadcastPayload(Map<String, dynamic> payloadMap) async {
    try {
      final String jsonPayload = jsonEncode(payloadMap);
      await _methodChannel.invokeMethod('broadcastPayload', {
        'payload': jsonPayload,
      });
    } on PlatformException catch (e) {
      print("Failed to broadcast payload: '${e.message}'.");
    }
  }

  void _startListeningForPayloads() {
    if (_meshSubscription != null) return;

    _meshSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        final String jsonPayload = event as String;
        _handleIncomingPayload(jsonPayload);
      },
      onError: (dynamic error) {
        print('Mesh Payload error: ${error.message}');
      },
    );
  }

  void _stopListeningForPayloads() {
    _meshSubscription?.cancel();
    _meshSubscription = null;
  }

  Future<void> _handleIncomingPayload(String jsonPayload) async {
    try {
      final data = jsonDecode(jsonPayload) as Map<String, dynamic>;

      // Control messages (not telemetry) are routed to their own listeners.
      final type = data['type']?.toString();
      if (type == 'hotspot_credentials') {
        _hotspotCredentialsController.add(data);
        return;
      }

      // Surface the peer's live position immediately (works fully offline).
      if (data['lat'] != null && data['lng'] != null) {
        _peerTelemetryController.add(data);
      }

      // Parse to our Isar DB Record
      final record = OfflineTelemetryRecord(
        userId: data['userId'] as String,
        groupId: data['groupId'] as String,
        lat: (data['lat'] as num).toDouble(),
        lng: (data['lng'] as num).toDouble(),
        altitude: (data['altitude'] as num).toDouble(),
        speed: (data['speed'] as num).toDouble(),
        battery: data['battery'] as int,
        recordedAt: DateTime.parse(data['recordedAt'] as String),
      );

      // Save to local Isar Database using SyncManager
      await _ref.read(syncManagerProvider).saveTelemetryRecord(record);
      print("Saved offline telemetry from user ${record.userId}");
    } catch (e) {
      print("Failed to parse mesh payload: $e");
    }
  }
}

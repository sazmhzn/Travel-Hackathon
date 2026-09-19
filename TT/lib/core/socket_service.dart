import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

final socketServiceProvider = Provider((ref) => SocketService());

class SocketService {
  IO.Socket? _socket;
  
  // Streams for incoming events
  final _peerLocationController = StreamController<Map<String, dynamic>>.broadcast();
  final _planUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _emergencyController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get peerLocationStream => _peerLocationController.stream;
  Stream<Map<String, dynamic>> get planUpdateStream => _planUpdateController.stream;
  Stream<Map<String, dynamic>> get emergencyStream => _emergencyController.stream;

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    // Backend host machine on the local network (same Wi-Fi/LAN as the device).
    const wsUrl = 'http://192.168.110.44:3000';

    _socket = IO.io(wsUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .setExtraHeaders({'Authorization': 'Bearer $token'})
        .setQuery({'token': token}) // Postman specifies token can be in query
        .build()
    );

    _socket!.onConnect((_) {
      print('Socket.IO Connected');
    });

    _socket!.onDisconnect((_) {
      print('Socket.IO Disconnected');
    });

    _socket!.onError((err) {
      print('Socket.IO Error: $err');
    });

    // Listeners based on Postman collection
    _socket!.on('member:location', (data) {
      if (data is Map<String, dynamic>) {
        _peerLocationController.add(data);
      }
    });

    _socket!.on('PlanUpdate', (data) {
      if (data is Map<String, dynamic>) {
        _planUpdateController.add(data);
      }
    });

    _socket!.on('emergency:distress', (data) {
      if (data is Map<String, dynamic>) {
        _emergencyController.add(data);
      }
    });

    _socket!.connect();
  }

  void joinGroup(String groupId) {
    if (_socket?.connected ?? false) {
      _socket!.emit('join_group', {'groupId': groupId});
    }
  }

  void leaveGroup(String groupId) {
    if (_socket?.connected ?? false) {
      _socket!.emit('leave_group', {'groupId': groupId});
    }
  }

  void emitLocationUpdate(String groupId, double lat, double lng, double altitude, double speed, int battery) {
    if (_socket?.connected ?? false) {
      _socket!.emit('location:update', {
        'groupId': groupId,
        'lat': lat,
        'lng': lng,
        'altitude': altitude,
        'speed': speed,
        'battery': battery,
        'timestamp': DateTime.now().toUtc().toIso8601String()
      });
    }
  }

  void ackPlan(String planId, String groupId) {
    if (_socket?.connected ?? false) {
      _socket!.emit('plan:ack', {
        'planId': planId,
        'groupId': groupId
      });
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}

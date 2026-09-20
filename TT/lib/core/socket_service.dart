import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

final socketServiceProvider = Provider((ref) => SocketService());

class SocketService {
  IO.Socket? _socket;
  String? _pendingGroupId;
  
  // Streams for incoming events
  final _peerLocationController = StreamController<Map<String, dynamic>>.broadcast();
  final _planUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _emergencyController = StreamController<Map<String, dynamic>>.broadcast();
  final _nearbyEmergencyController = StreamController<Map<String, dynamic>>.broadcast();
  final _emergencyResolvedController = StreamController<Map<String, dynamic>>.broadcast();
  final _memberFoundController = StreamController<Map<String, dynamic>>.broadcast();
  // Membership/status/route changes, so screens can refetch instead of going stale.
  final _groupEventController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get peerLocationStream => _peerLocationController.stream;
  Stream<Map<String, dynamic>> get planUpdateStream => _planUpdateController.stream;
  Stream<Map<String, dynamic>> get emergencyStream => _emergencyController.stream;
  Stream<Map<String, dynamic>> get nearbyEmergencyStream => _nearbyEmergencyController.stream;
  Stream<Map<String, dynamic>> get emergencyResolvedStream => _emergencyResolvedController.stream;
  Stream<Map<String, dynamic>> get memberFoundStream => _memberFoundController.stream;
  Stream<Map<String, dynamic>> get groupEventStream => _groupEventController.stream;

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    // Backend host machine on the local network (same Wi-Fi/LAN as the device).
    const wsUrl = 'http://192.168.110.44:3000';

    _socket = IO.io(wsUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .setAuth({'token': token}) // Socket.IO handshake auth (backend reads handshake.auth.token)
        .setExtraHeaders({'Authorization': 'Bearer $token'})
        .setQuery({'token': token}) // Postman specifies token can be in query
        .build()
    );

    _socket!.onConnect((_) {
      print('Socket.IO Connected');
      // Re-join the active expedition room on (re)connect so live member
      // locations keep flowing.
      if (_pendingGroupId != null) {
        _socket!.emit('join_group', {'groupId': _pendingGroupId});
      }
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

    _socket!.on('emergency:nearby', (data) {
      if (data is Map<String, dynamic>) {
        _nearbyEmergencyController.add(data);
      }
    });

    _socket!.on('emergency:resolved', (data) {
      if (data is Map<String, dynamic>) {
        _emergencyResolvedController.add(data);
      }
    });

    _socket!.on('member:found', (data) {
      if (data is Map<String, dynamic>) {
        _memberFoundController.add(data);
      }
    });

    // Group membership/status/route changes. `event` tags the kind so a single
    // stream can drive refetches on any screen.
    for (final entry in const {
      'group:member_joined': 'member_joined',
      'group:member_removed': 'member_removed',
      'group:updated': 'group_updated',
      'group:removed': 'group_removed',
      'group:deleted': 'group_deleted',
      'route:recorded': 'route_recorded',
    }.entries) {
      _socket!.on(entry.key, (data) {
        if (data is Map) {
          _groupEventController.add({...data.cast<String, dynamic>(), 'event': entry.value});
        }
      });
    }

    _socket!.connect();
  }

  void joinGroup(String groupId) {
    _pendingGroupId = groupId;
    if (_socket?.connected ?? false) {
      _socket!.emit('join_group', {'groupId': groupId});
    }
  }

  void leaveGroup(String groupId) {
    if (_pendingGroupId == groupId) _pendingGroupId = null;
    if (_socket?.connected ?? false) {
      _socket!.emit('leave_group', {'groupId': groupId});
    }
  }

  /// Tells the expedition that [userId] has been found by a searcher.
  void markMemberFound(String groupId, String userId, String foundByName) {
    if (_socket?.connected ?? false) {
      _socket!.emit('member:found', {
        'groupId': groupId,
        'userId': userId,
        'foundByName': foundByName,
      });
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
    _pendingGroupId = null;
  }
}

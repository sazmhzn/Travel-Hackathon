import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';

final emergencyServiceProvider = Provider((ref) => EmergencyService(ref));

class EmergencyService {
  final Ref _ref;

  EmergencyService(this._ref);

  Future<bool> triggerRescueMode(String groupId, double lat, double lng, int? battery, String reason) async {
    // 1. Tell Native Kotlin layer to maximize Nearby Connections P2P Advertising
    // (This would be another MethodChannel call to NearbyMeshService)

    // 2. Try sending immediately via Internet if available
    try {
      final client = _ref.read(apiClientProvider).client;
      final response = await client.post(
        '/emergency/trigger',
        data: {
          "groupId": groupId,
          "lat": lat,
          "lng": lng,
          "battery": ?battery,
          "reason": reason
        }
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("Failed to trigger emergency over network (offline?): $e");
      return false;
    }
  }

  /// Clears active Rescue Mode alerts for the expedition (optionally one user).
  Future<bool> resolveEmergency(String groupId, {String? userId}) async {
    try {
      final client = _ref.read(apiClientProvider).client;
      final response = await client.post(
        '/emergency/resolve',
        data: {
          "groupId": groupId,
          "userId": ?userId,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Failed to resolve emergency: $e");
      return false;
    }
  }
}

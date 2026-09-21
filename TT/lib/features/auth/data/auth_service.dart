import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';
import '../../../core/device_identity.dart';
import '../../../core/socket_service.dart';
import '../../map/data/location_tracking_service.dart';

final authServiceProvider = Provider((ref) => AuthService(ref));

class AuthService {
  final Ref _ref;

  AuthService(this._ref);

  /// Signs in and returns the authenticated user's profile (or null on
  /// failure) so callers can route based on the user's role.
  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final client = _ref.read(apiClientProvider).client;
      // Bind this device's Bluetooth identity to the profile on login.
      final identity = await _ref.read(deviceIdentityProvider).get();
      final response = await client.post('/auth/login', data: {
        'email': email,
        'password': password,
        'deviceId': identity['deviceId'],
        'bluetoothName': identity['bluetoothName'],
      });

      if (response.statusCode == 200) {
        final token = response.data['token'];
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
          final profile = await getProfile();
          if (profile?['name'] != null) {
            await prefs.setString('user_name', profile!['name'].toString());
          }
          return profile;
        }
      }
      return null;
    } catch (e) {
      if (e is DioException) {
        debugPrint('Login error details: ${e.response?.data}');
      }
      debugPrint('Login error: $e');
      return null;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role, // GUIDE or MEMBER
  }) async {
    try {
      final client = _ref.read(apiClientProvider).client;
      final identity = await _ref.read(deviceIdentityProvider).get();
      final response = await client.post('/auth/register', data: {
        'email': email,
        'password': password,
        'name': name,
        'phone': phone,
        'role': role,
        'deviceId': identity['deviceId'],
        'bluetoothName': identity['bluetoothName'],
      });

      if (response.statusCode == 201) {
        final token = response.data['token'];
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
          await prefs.setString('user_name', name);
          return true;
        }
      }
      return false;
    } catch (e) {
      if (e is DioException) {
        debugPrint('Registration error details: ${e.response?.data}');
      }
      debugPrint('Registration error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final client = _ref.read(apiClientProvider).client;
      final response = await client.get('/auth/me');
      if (response.statusCode == 200) {
        final data = response.data;
        // Backend returns { user: {...} }.
        if (data is Map<String, dynamic> && data['user'] is Map) {
          return (data['user'] as Map).cast<String, dynamic>();
        }
        return data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Get profile error: $e');
      return null;
    }
  }

  Future<void> logout() async {
    // Stop live tracking/advertising and drop realtime + cached expedition
    // state so nothing keeps broadcasting or shows stale data after sign-out.
    try {
      await _ref.read(locationTrackingServiceProvider).stopTracking();
    } catch (_) {
      // Tracking may not be running; ignore.
    }
    _ref.read(socketServiceProvider).disconnect();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('active_group_id');
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith('roster_') ||
          key.startsWith('group_status_') ||
          key.startsWith('missing_threshold_')) {
        await prefs.remove(key);
      }
    }
  }

  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('jwt_token');
  }
}

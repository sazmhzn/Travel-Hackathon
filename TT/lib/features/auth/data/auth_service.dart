import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';

final authServiceProvider = Provider((ref) => AuthService(ref));

class AuthService {
  final Ref _ref;

  AuthService(this._ref);

  Future<bool> login(String email, String password) async {
    try {
      final client = _ref.read(apiClientProvider).client;
      final response = await client.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final token = response.data['token'];
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
          // Optional: Fetch user profile
          await getProfile();
          return true;
        }
      }
      return false;
    } catch (e) {
      if (e is DioException) {
        print('Login error details: ${e.response?.data}');
      }
      print('Login error: $e');
      return false;
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
      final response = await client.post('/auth/register', data: {
        'email': email,
        'password': password,
        'name': name,
        'phone': phone,
        'role': role,
      });

      if (response.statusCode == 201) {
        final token = response.data['token'];
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
          return true;
        }
      }
      return false;
    } catch (e) {
      if (e is DioException) {
        print('Registration error details: ${e.response?.data}');
      }
      print('Registration error: $e');
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
      print('Get profile error: $e');
      return null;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('jwt_token');
  }
}

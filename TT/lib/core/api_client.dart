import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final apiClientProvider = Provider((ref) => ApiClient());

/// Overridable at build time:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000/api`
///
/// The default targets the Android emulator host loopback (10.0.2.2).
/// For a physical device over USB, run `adb reverse tcp:3000 tcp:3000` and
/// pass `--dart-define=API_BASE_URL=http://127.0.0.1:3000/api`.
const String _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000/api',
);

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: _apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ));
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('jwt_token');
          
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Handle global errors here (e.g., 401 Unauthorized)
          return handler.next(e);
        }
      )
    );
  }

  Dio get client => _dio;
}

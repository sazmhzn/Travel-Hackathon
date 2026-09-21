import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'storage/storage_keys.dart';

final apiClientProvider = Provider((ref) => ApiClient());

/// REST base URL, owned by [AppConfig] (overridable with
/// `--dart-define=API_BASE_URL=...`). Kept as a top-level constant because
/// `socket_service.dart` derives the WebSocket origin from it.
const String apiBaseUrl = AppConfig.baseUrl;

class ApiClient {
  /// Invoked when the server rejects the token (401) so the app can return to
  /// the login screen. Wired up in main.dart.
  static VoidCallback? onUnauthorized;

  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
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
          final token = prefs.getString(StorageKeys.jwtToken);
          
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // Expired/invalid token: clear it and send the user back to login
          // instead of silently returning empty data everywhere.
          if (e.response?.statusCode == 401) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(StorageKeys.jwtToken);
            ApiClient.onUnauthorized?.call();
          }
          return handler.next(e);
        }
      )
    );
  }

  Dio get client => _dio;
}

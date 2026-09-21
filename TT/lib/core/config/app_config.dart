import 'package:flutter/foundation.dart';

/// Compile-time configuration, single source of truth for the API base URL.
///
/// Override at build time:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000/api`
///
/// The default targets the backend host on the local network, so a physical
/// device and the host must share the same Wi-Fi/LAN.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.69:3000/api',
  );

  /// REST base URL.
  static const String baseUrl = apiBaseUrl;

  /// WebSocket origin derived from the REST base (drops a trailing `/api`).
  static String get socketOrigin =>
      baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

  static bool get isDebug => kDebugMode;

  static bool get isRelease => kReleaseMode;
}

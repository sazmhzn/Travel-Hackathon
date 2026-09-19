import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final hotspotServiceProvider = Provider((ref) => HotspotService());

/// Bridges to the native Android local-only hotspot so an expedition can keep
/// sharing live locations over a LAN when there is no internet.
class HotspotService {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.example.tt/hotspot_control',
  );

  Future<bool> hasInternet() async {
    try {
      return await _methodChannel.invokeMethod<bool>('hasInternet') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Starts the guide's hotspot and returns its `{ssid, password}`, or null if
  /// the device does not support it.
  Future<Map<String, String>?> startHotspot() async {
    try {
      final value = await _methodChannel.invokeMethod<dynamic>('startHotspot');
      if (value is Map) {
        return {
          'ssid': value['ssid']?.toString() ?? '',
          'password': value['password']?.toString() ?? '',
        };
      }
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> stopHotspot() async {
    try {
      await _methodChannel.invokeMethod('stopHotspot');
    } on PlatformException {
      // Ignore: hotspot control is best-effort.
    }
  }

  /// Joins the guide's hotspot. Returns true once connected.
  Future<bool> connectToHotspot(String ssid, String password) async {
    try {
      return await _methodChannel.invokeMethod<bool>('connectToHotspot', {
            'ssid': ssid,
            'password': password,
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _methodChannel.invokeMethod('disconnect');
    } on PlatformException {
      // Ignore.
    }
  }
}

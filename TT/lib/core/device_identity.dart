import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final deviceIdentityProvider = Provider((ref) => DeviceIdentity());

/// The device's stable identity used for Bluetooth/mesh discovery: a device id
/// (Android ID when available, otherwise a generated one) plus the Bluetooth
/// display name. Both are persisted and sent to the backend on login.
class DeviceIdentity {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.example.tt/device_identity',
  );

  Map<String, String>? _cached;

  Future<Map<String, String>> get() async {
    if (_cached != null) return _cached!;

    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('device_id') ?? '';
    var bluetoothName = prefs.getString('bluetooth_name') ?? '';

    try {
      final native =
          await _methodChannel.invokeMethod<dynamic>('getIdentity');
      if (native is Map) {
        final nativeId = native['deviceId']?.toString();
        final nativeName = native['bluetoothName']?.toString();
        if (nativeId != null && nativeId.isNotEmpty) deviceId = nativeId;
        if (nativeName != null && nativeName.isNotEmpty) {
          bluetoothName = nativeName;
        }
      }
    } on PlatformException {
      // Fall back to the locally generated/stored values below.
    }

    if (deviceId.isEmpty) deviceId = _generateDeviceId();
    if (bluetoothName.isEmpty) {
      bluetoothName = prefs.getString('user_name') ?? 'Traveler';
    }

    await prefs.setString('device_id', deviceId);
    await prefs.setString('bluetooth_name', bluetoothName);

    _cached = {'deviceId': deviceId, 'bluetoothName': bluetoothName};
    return _cached!;
  }

  /// The identifier peers search for when this device goes missing.
  Future<String> get searchIdentifier async {
    final identity = await get();
    return identity['deviceId']!;
  }

  String _generateDeviceId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return 'dev-${List.generate(16, (_) => chars[rand.nextInt(chars.length)]).join()}';
  }
}

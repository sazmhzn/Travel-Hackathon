/// Centralized SharedPreferences keys. Never write a raw key string in a
/// feature — add it here.
class StorageKeys {
  StorageKeys._();

  // Auth
  static const String jwtToken = 'jwt_token';
  static const String userName = 'user_name';

  // Device identity (Bluetooth / mesh)
  static const String deviceId = 'device_id';
  static const String bluetoothName = 'bluetooth_name';

  // Active expedition
  static const String activeGroupId = 'active_group_id';

  // Offline map region
  static const String destinationName = 'destination_name';
  static const String minLat = 'min_lat';
  static const String minLng = 'min_lng';
  static const String maxLat = 'max_lat';
  static const String maxLng = 'max_lng';
  static const String onboardingComplete = 'onboarding_complete';

  // Per-expedition, keyed by group id
  static String roster(String groupId) => 'roster_$groupId';
  static String groupStatus(String groupId) => 'group_status_$groupId';
  static String missingThreshold(String groupId) =>
      'missing_threshold_$groupId';
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final localStorageServiceProvider =
    Provider<LocalStorageService>((ref) => LocalStorageService());

/// Thin typed wrapper over [SharedPreferences]. Resolves the instance lazily so
/// callers never need to await setup.
class LocalStorageService {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> getString(String key) async => (await _prefs).getString(key);

  Future<bool> setString(String key, String value) async =>
      (await _prefs).setString(key, value);

  Future<int?> getInt(String key) async => (await _prefs).getInt(key);

  Future<bool> setInt(String key, int value) async =>
      (await _prefs).setInt(key, value);

  Future<double?> getDouble(String key) async => (await _prefs).getDouble(key);

  Future<bool> setDouble(String key, double value) async =>
      (await _prefs).setDouble(key, value);

  Future<bool?> getBool(String key) async => (await _prefs).getBool(key);

  Future<bool> setBool(String key, bool value) async =>
      (await _prefs).setBool(key, value);

  Future<List<String>?> getStringList(String key) async =>
      (await _prefs).getStringList(key);

  Future<bool> containsKey(String key) async => (await _prefs).containsKey(key);

  Future<bool> remove(String key) async => (await _prefs).remove(key);
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Thin wrapper around SharedPreferences. Mirrors src/storage.js.
class Storage {
  static const _secure = FlutterSecureStorage();
  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  static Future<void> setLoggedIn(bool value) async {
    final p = await _prefs;
    await p.setString('isLoggedIn', value ? 'true' : 'false');
  }

  static Future<bool> isLoggedIn() async {
    final p = await _prefs;
    return p.getString('isLoggedIn') == 'true' &&
        await _secure.read(key: 'access_token') != null;
  }

  static Future<void> setUser({
    required String userId,
    String? name,
    String? email,
  }) async {
    final p = await _prefs;
    await p.setString('user_id', userId);
    if (name != null) await p.setString('user_name', name);
    if (email != null) await p.setString('user_email', email);
  }

  static Future<Map<String, String?>> getUser() async {
    final p = await _prefs;
    return {
      'user_id': p.getString('user_id'),
      'name': p.getString('user_name'),
      'email': p.getString('user_email'),
    };
  }

  // --- JWT tokens (v2 API) ---
  static Future<void> setTokens({
    required String access,
    required String refresh,
  }) async {
    await _secure.write(key: 'access_token', value: access);
    await _secure.write(key: 'refresh_token', value: refresh);
  }

  static Future<void> setAccessToken(String access) async {
    await _secure.write(key: 'access_token', value: access);
  }

  static Future<String?> getAccessToken() async {
    return _secure.read(key: 'access_token');
  }

  static Future<String?> getRefreshToken() async {
    return _secure.read(key: 'refresh_token');
  }

  static Future<void> clearUser() async {
    final p = await _prefs;
    await p.remove('user_id');
    await p.remove('user_name');
    await p.remove('user_email');
    await _secure.delete(key: 'access_token');
    await _secure.delete(key: 'refresh_token');
    await p.setString('isLoggedIn', 'false');
  }

  static Future<String?> getThemeMode() async {
    final p = await _prefs;
    return p.getString('themeMode');
  }

  static Future<void> setThemeMode(String mode) async {
    final p = await _prefs;
    await p.setString('themeMode', mode);
  }
}

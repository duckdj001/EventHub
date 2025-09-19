import 'package:shared_preferences/shared_preferences.dart';

class DeviceTokenStorage {
  static const _tokenKey = 'push_token';
  static const _userKey = 'push_token_user';

  static Future<void> save({required String token, String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    if (userId != null) {
      await prefs.setString(_userKey, userId);
    } else {
      await prefs.remove(_userKey);
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) return null;
    return token;
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_userKey);
    if (id == null || id.isEmpty) return null;
    return id;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}

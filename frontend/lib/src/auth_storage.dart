import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  const AuthStorage._();

  static const _tokenKey = 'musicflow.auth.token';

  static Future<String?> loadToken() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey)?.trim();
    return token == null || token.isEmpty ? null : token;
  }

  static Future<void> saveToken(String token) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, token);
  }

  static Future<void> clearToken() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
  }
}

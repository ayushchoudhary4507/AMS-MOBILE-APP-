import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _roleKey = 'user_role';

  // Save Token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Get Token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Save User Avatar per email/ID
  static Future<void> saveUserAvatar(String emailOrId, String avatar) async {
    if (emailOrId.trim().isEmpty || avatar.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'user_avatar_${emailOrId.trim().toLowerCase()}';
    await prefs.setString(key, avatar);
  }

  // Get User Avatar per email/ID
  static Future<String?> getUserAvatar(String emailOrId) async {
    if (emailOrId.trim().isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final key = 'user_avatar_${emailOrId.trim().toLowerCase()}';
    return prefs.getString(key);
  }

  // Save User
  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));

    final email = (user['email'] ?? user['id'] ?? user['_id'])?.toString();
    final avatar = (user['avatar'] ??
            user['profilePicture'] ??
            user['image'] ??
            user['avatarUrl'] ??
            user['photo'] ??
            user['profile_picture'])
        ?.toString();

    if (email != null && email.isNotEmpty && avatar != null && avatar.isNotEmpty) {
      await saveUserAvatar(email, avatar);
    }
  }

  // Get User
  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_userKey);
    if (userStr == null || userStr.isEmpty) return null;
    try {
      final decoded = jsonDecode(userStr);
      Map<String, dynamic>? userMap;
      if (decoded is Map<String, dynamic>) {
        userMap = Map<String, dynamic>.from(decoded);
      } else if (decoded is Map) {
        userMap = Map<String, dynamic>.from(decoded);
      }

      if (userMap != null) {
        final email = (userMap['email'] ?? userMap['id'] ?? userMap['_id'])?.toString();
        final currentAvatar = (userMap['avatar'] ??
                userMap['profilePicture'] ??
                userMap['image'] ??
                userMap['avatarUrl'] ??
                userMap['photo'] ??
                userMap['profile_picture'])
            ?.toString();

        if ((currentAvatar == null || currentAvatar.isEmpty) && email != null) {
          final cachedAvatar = await getUserAvatar(email);
          if (cachedAvatar != null && cachedAvatar.isNotEmpty) {
            userMap['avatar'] = cachedAvatar;
            userMap['profilePicture'] = cachedAvatar;
            userMap['image'] = cachedAvatar;
          }
        }
      }
      return userMap;
    } catch (_) {}
    return null;
  }

  // Save Role
  static Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  // Get Role
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  // Clear Session Data (Logout)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_roleKey);
    await prefs.remove('last_route');
  }

  // Is Logged In
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Save Theme Mode (true = dark, false = light)
  static Future<void> saveThemeMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_mode', isDark);
  }

  // Get Theme Mode
  static Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('theme_mode') ?? true;
  }

  // Save Last Open Route
  static Future<void> saveLastRoute(String route) async {
    if (route == '/' ||
        route == '/login' ||
        route == '/welcome' ||
        route == '/register' ||
        route == '/biometric-lock') {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_route', route);
  }

  // Get Last Open Route
  static Future<String?> getLastRoute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_route');
  }
}

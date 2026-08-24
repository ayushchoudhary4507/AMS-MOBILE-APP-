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

  static final Map<String, String> avatarCache = {};

  // Save Today Attendance cache per user/date
  static Future<void> saveTodayAttendance(
    String emailOrId,
    Map<String, dynamic> att,
  ) async {
    if (emailOrId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final keyLower = emailOrId.trim().toLowerCase();
    final key = 'today_att_${keyLower}_$dateStr';

    final map = Map<String, dynamic>.from(att);
    final user = await getUser();
    map['userId'] ??= user?['id'] ?? user?['_id'] ?? emailOrId;
    map['email'] ??= user?['email'] ?? (emailOrId.contains('@') ? emailOrId : null);
    map['name'] ??= user?['name'] ?? 'Employee';
    map['status'] ??= 'Present';
    map['checkIn'] ??= now.toIso8601String();
    map['date'] ??= now.toIso8601String();

    await prefs.setString(key, jsonEncode(map));
  }

  // Get Today Attendance cache per user/date
  static Future<Map<String, dynamic>?> getTodayAttendance(
    String emailOrId,
  ) async {
    if (emailOrId.trim().isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final keyLower = emailOrId.trim().toLowerCase();
    final key = 'today_att_${keyLower}_$dateStr';
    final raw = prefs.getString(key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  // Get all locally saved today attendance records
  static Future<List<Map<String, dynamic>>> getAllSavedTodayAttendances() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final prefix = 'today_att_';
      final suffix = '_$dateStr';
      final results = <Map<String, dynamic>>[];
      for (final key in prefs.getKeys()) {
        if (key.startsWith(prefix) && key.endsWith(suffix)) {
          final raw = prefs.getString(key);
          if (raw != null && raw.isNotEmpty) {
            try {
              final decoded = jsonDecode(raw);
              if (decoded is Map) {
                results.add(Map<String, dynamic>.from(decoded));
              }
            } catch (_) {}
          }
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  // Save User Avatar per email/ID
  static Future<void> saveUserAvatar(String emailOrId, String avatar) async {
    if (emailOrId.trim().isEmpty || avatar.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final keyLower = emailOrId.trim().toLowerCase();
    final key = 'user_avatar_$keyLower';
    await prefs.setString(key, avatar);
    avatarCache[keyLower] = avatar;
  }

  // Get User Avatar per email/ID
  static Future<String?> getUserAvatar(String emailOrId) async {
    if (emailOrId.trim().isEmpty) return null;
    final keyLower = emailOrId.trim().toLowerCase();
    if (avatarCache.containsKey(keyLower) &&
        avatarCache[keyLower]!.isNotEmpty) {
      return avatarCache[keyLower];
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'user_avatar_$keyLower';
    final saved = prefs.getString(key);
    if (saved != null && saved.isNotEmpty) {
      avatarCache[keyLower] = saved;
    }
    return saved;
  }

  // Save User
  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));

    final email = user['email']?.toString();
    final id = (user['id'] ?? user['_id'])?.toString();
    final name = user['name']?.toString();
    final avatar =
        (user['avatar'] ??
                user['profilePicture'] ??
                user['profileImage'] ??
                user['profile_picture'] ??
                user['image'] ??
                user['avatarUrl'] ??
                user['photo'])
            ?.toString();

    if (avatar != null && avatar.isNotEmpty) {
      if (email != null && email.isNotEmpty) {
        await saveUserAvatar(email, avatar);
      }
      if (id != null && id.isNotEmpty) await saveUserAvatar(id, avatar);
      if (name != null && name.isNotEmpty) await saveUserAvatar(name, avatar);
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
        final email = userMap['email']?.toString();
        final id = (userMap['id'] ?? userMap['_id'])?.toString();
        final name = userMap['name']?.toString();
        final currentAvatar =
            (userMap['avatar'] ??
                    userMap['profilePicture'] ??
                    userMap['profileImage'] ??
                    userMap['profile_picture'] ??
                    userMap['image'] ??
                    userMap['avatarUrl'] ??
                    userMap['photo'])
                ?.toString();

        if (currentAvatar != null &&
            (currentAvatar.startsWith('AAAB') || currentAvatar.startsWith('xtbHVj'))) {
          userMap.remove('avatar');
          userMap.remove('profilePicture');
          userMap.remove('profileImage');
          userMap.remove('profile_picture');
          userMap.remove('image');
          if (email != null) avatarCache.remove(email.trim().toLowerCase());
          if (id != null) avatarCache.remove(id.trim().toLowerCase());
          if (name != null) avatarCache.remove(name.trim().toLowerCase());
        } else if ((currentAvatar == null || currentAvatar.isEmpty) && email != null) {
          final cachedAvatar = await getUserAvatar(email);
          if (cachedAvatar != null &&
              cachedAvatar.isNotEmpty &&
              !cachedAvatar.startsWith('AAAB') &&
              !cachedAvatar.startsWith('xtbHVj')) {
            userMap['avatar'] = cachedAvatar;
            userMap['profilePicture'] = cachedAvatar;
            userMap['profileImage'] = cachedAvatar;
            userMap['profile_picture'] = cachedAvatar;
            userMap['image'] = cachedAvatar;
          }
        } else if (currentAvatar != null && currentAvatar.isNotEmpty) {
          userMap['avatar'] = currentAvatar;
          userMap['profilePicture'] = currentAvatar;
          userMap['profileImage'] = currentAvatar;
          userMap['profile_picture'] = currentAvatar;
          userMap['image'] = currentAvatar;
          if (email != null && email.isNotEmpty) {
            avatarCache[email.trim().toLowerCase()] = currentAvatar;
          }
          if (id != null && id.isNotEmpty) {
            avatarCache[id.trim().toLowerCase()] = currentAvatar;
          }
          if (name != null && name.isNotEmpty) {
            avatarCache[name.trim().toLowerCase()] = currentAvatar;
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
    await prefs.remove('device_token');
  }

  // Save Device / FCM Token
  static Future<void> saveDeviceToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_token', token);
  }

  // Get Device / FCM Token
  static Future<String?> getDeviceToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_token');
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

  // Save My Leaves cache per user
  static Future<void> saveMyLeaves(
    String emailOrId,
    List<dynamic> leaves,
  ) async {
    if (emailOrId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final keyLower = emailOrId.trim().toLowerCase();
    await prefs.setString('my_leaves_$keyLower', jsonEncode(leaves));
  }

  // Get My Leaves cache per user
  static Future<List<dynamic>> getMyLeaves(String emailOrId) async {
    if (emailOrId.trim().isEmpty) return [];
    final prefs = await SharedPreferences.getInstance();
    final keyLower = emailOrId.trim().toLowerCase();
    final raw = prefs.getString('my_leaves_$keyLower');
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    return [];
  }

  // Save All Leaves cache (Admin)
  static Future<void> saveAllLeaves(List<dynamic> leaves) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('all_leaves_cache', jsonEncode(leaves));
  }

  // Get All Leaves cache (Admin)
  static Future<List<dynamic>> getAllLeaves() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('all_leaves_cache');
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    return [];
  }

  // Save Daily QR Session (Admin)
  static Future<void> saveDailyQRSession(Map<String, dynamic> session) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await prefs.setString('daily_qr_session_$dateStr', jsonEncode(session));
    await prefs.setString('daily_qr_latest_date', dateStr);
  }

  // Get Daily QR Session for Today (Admin)
  static Future<Map<String, dynamic>?> getDailyQRSession() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final raw = prefs.getString('daily_qr_session_$dateStr');
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }
}


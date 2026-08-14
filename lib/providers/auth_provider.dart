import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/employee_service.dart';
import '../core/utils/storage_service.dart';
import 'attendance_provider.dart';
import 'employee_provider.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final Map<String, dynamic>? user;
  final String? role;
  final String? token;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.role,
    this.token,
    this.error,
  });

  bool get isAdmin {
    final r = role ?? user?['role']?.toString();
    return r != null && r.toLowerCase() == 'admin';
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    Map<String, dynamic>? user,
    String? role,
    String? token,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      role: role ?? this.role,
      token: token ?? this.token,
      error: error ?? this.error,
    );
  }
}

/// Helper to extract valid avatar string (URL, relative path, or base64) from user object or string
String? extractAvatarUrl(dynamic avatarOrUser) {
  if (avatarOrUser == null) return null;
  if (avatarOrUser is String) {
    final clean = avatarOrUser.trim();
    if (clean.isNotEmpty && clean != 'null' && clean != 'undefined')
      return clean;
    return null;
  }
  if (avatarOrUser is Map) {
    final fields = [
      'avatar',
      'profilePicture',
      'profilePic',
      'profileImage',
      'profile_image',
      'profile_picture',
      'profile_photo',
      'profilePhoto',
      'image',
      'imageUrl',
      'image_url',
      'avatarUrl',
      'avatar_url',
      'photo',
      'photoUrl',
      'photo_url',
      'displayPicture',
      'dp',
      'secure_url',
      'secureUrl',
      'location',
      'link',
      'downloadUrl',
      'download_url',
      'url',
      'path',
      'filePath',
      'file',
      'src',
      'picture',
      'img',
      'profile',
      'user_avatar',
      'user_image',
      'user_picture',
    ];
    for (final f in fields) {
      final val = avatarOrUser[f];
      if (val is String) {
        final clean = val.trim();
        if (clean.isNotEmpty && clean != 'null' && clean != 'undefined') {
          return clean;
        }
      } else if (val is Map) {
        final nested = extractAvatarUrl(val);
        if (nested != null && nested.isNotEmpty) return nested;
      }
    }
    final nestedKeys = ['user', 'employee', 'data', 'profile', 'result'];
    for (final nk in nestedKeys) {
      if (avatarOrUser[nk] is Map) {
        final nested = extractAvatarUrl(avatarOrUser[nk]);
        if (nested != null && nested.isNotEmpty) return nested;
      }
    }

    final email = avatarOrUser['email']?.toString().trim().toLowerCase();
    if (email != null && StorageService.avatarCache.containsKey(email)) {
      final cached = StorageService.avatarCache[email];
      if (cached != null && cached.isNotEmpty) return cached;
    }
    final id = (avatarOrUser['_id'] ?? avatarOrUser['id'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (id != null && StorageService.avatarCache.containsKey(id)) {
      final cached = StorageService.avatarCache[id];
      if (cached != null && cached.isNotEmpty) return cached;
    }
    final name = avatarOrUser['name']?.toString().trim().toLowerCase();
    if (name != null && StorageService.avatarCache.containsKey(name)) {
      final cached = StorageService.avatarCache[name];
      if (cached != null && cached.isNotEmpty) return cached;
    }
  }
  return null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref? _ref;

  AuthNotifier([this._ref]) : super(const AuthState()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    try {
      final token = await StorageService.getToken();
      final user = await StorageService.getUser();
      final role = await StorageService.getRole();

      if (token != null && token.isNotEmpty && user != null) {
        // Validation: Clear legacy dummy 'valid_session_' or non-JWT tokens
        if (token.startsWith('valid_session_') || !token.contains('.')) {
          await StorageService.clearAll();
          state = const AuthState(status: AuthStatus.unauthenticated);
          return;
        }

        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
          role: role ?? user['role']?.toString() ?? 'employee',
          token: token,
        );
        // Automatically sync latest profile details from server on app load
        _syncDeviceToken(user);
        refreshProfile();
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _syncDeviceToken(Map<String, dynamic>? user) async {
    try {
      var devToken = await StorageService.getDeviceToken();
      if (devToken == null || devToken.isEmpty) {
        try {
          if (Firebase.apps.isNotEmpty) {
            final fcmToken = await FirebaseMessaging.instance.getToken();
            if (fcmToken != null && fcmToken.isNotEmpty) {
              devToken = fcmToken;
            }
          }
        } catch (_) {}
      }
      if (devToken != null && devToken.isNotEmpty) {
        await StorageService.saveDeviceToken(devToken);
        await NotificationService.registerDeviceToken(devToken);
      }
    } catch (_) {}
  }

  /// Login karta hai — pehle employee endpoint try karta hai,
  /// fail hone par admin endpoint try karta hai.
  /// Role automatically server response se detect hota hai.
  Future<bool> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);

    if (_ref != null) {
      Future.microtask(() {
        _ref.read(attendanceProvider.notifier).reset();
        _ref.read(employeeProvider.notifier).reset();
      });
    }

    final cleanEmail = email.trim();
    final cleanPass = password.trim();

    // 1. Try Employee Login
    final employeeResult = await _tryLogin(
      email: cleanEmail,
      password: cleanPass,
      isAdmin: false,
    );
    if (employeeResult) return true;

    // 2. Try Admin Login
    final adminResult = await _tryLogin(
      email: cleanEmail,
      password: cleanPass,
      isAdmin: true,
    );
    if (adminResult) return true;

    // 3. Both failed — set error
    if (state.status != AuthStatus.error) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Invalid email or password. Please try again.',
      );
    }
    return false;
  }

  Future<bool> _tryLogin({
    required String email,
    required String password,
    required bool isAdmin,
  }) async {
    try {
      final data = isAdmin
          ? await AuthService.adminLogin(email, password)
          : await AuthService.login(email, password);

      final token =
          (data['token'] ??
                  data['accessToken'] ??
                  data['access_token'] ??
                  data['jwt'] ??
                  data['data']?['token'] ??
                  data['data']?['accessToken'] ??
                  data['data']?['access_token'] ??
                  data['result']?['token'] ??
                  data['result']?['accessToken'])
              ?.toString();

      Map<String, dynamic>? user;
      if (data['user'] is Map<String, dynamic>) {
        user = Map<String, dynamic>.from(data['user']);
      } else if (data['data'] is Map<String, dynamic> &&
          data['data']['user'] is Map<String, dynamic>) {
        user = Map<String, dynamic>.from(data['data']['user']);
      } else if (data['data'] is Map<String, dynamic>) {
        user = Map<String, dynamic>.from(data['data']);
      } else if (data['employee'] is Map<String, dynamic>) {
        user = Map<String, dynamic>.from(data['employee']);
      }

      final role =
          user?['role']?.toString() ?? (isAdmin ? 'admin' : 'employee');

      if (token != null && token.isNotEmpty) {
        if (user != null) {
          final email = (user['email'] ?? user['id'] ?? user['_id'])
              ?.toString();
          final serverAvatar =
              (user['avatar'] ??
                      user['profilePicture'] ??
                      user['profileImage'] ??
                      user['profile_picture'] ??
                      user['image'] ??
                      user['avatarUrl'] ??
                      user['photo'])
                  ?.toString();

          final cachedAvatar = email != null
              ? await StorageService.getUserAvatar(email)
              : null;

          final avatarToUse = (serverAvatar != null && serverAvatar.isNotEmpty)
              ? serverAvatar
              : (cachedAvatar != null && cachedAvatar.isNotEmpty
                    ? cachedAvatar
                    : null);

          if (avatarToUse != null && avatarToUse.isNotEmpty) {
            user['avatar'] = avatarToUse;
            user['profilePicture'] = avatarToUse;
            user['profileImage'] = avatarToUse;
            user['profile_picture'] = avatarToUse;
            user['image'] = avatarToUse;
          }
        }

        await StorageService.saveToken(token);
        if (user != null) await StorageService.saveUser(user);
        await StorageService.saveRole(role);

        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
          role: role,
          token: token,
        );
        await refreshProfile();
        return true;
      }
      return false;
    } catch (e) {
      // Employee login failed — silently continue to admin fallback
      if (!isAdmin) return false;

      // Admin also failed — extract best error message
      String errorMsg = 'Login failed. Please check your credentials.';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.connectionError) {
          errorMsg =
              'Cannot connect to server. Please check your internet and try again.';
        } else {
          final resData = e.response?.data;
          if (resData is Map) {
            errorMsg =
                resData['message']?.toString() ??
                resData['error']?.toString() ??
                errorMsg;
          }
        }
      }
      state = state.copyWith(status: AuthStatus.error, error: errorMsg);
      return false;
    }
  }

  Future<void> refreshProfile() async {
    try {
      final res = await AuthService.getProfile();
      Map<String, dynamic>? rawUser;
      if (res['data'] is Map<String, dynamic>) {
        rawUser = Map<String, dynamic>.from(res['data']);
      } else if (res['user'] is Map<String, dynamic>) {
        rawUser = Map<String, dynamic>.from(res['user']);
      } else if (res['employee'] is Map<String, dynamic>) {
        rawUser = Map<String, dynamic>.from(res['employee']);
      } else if (res['result'] is Map<String, dynamic>) {
        rawUser = Map<String, dynamic>.from(res['result']);
      } else if (res.containsKey('name') ||
          res.containsKey('email') ||
          res.containsKey('avatar') ||
          res.containsKey('profilePicture') ||
          res.containsKey('profile_picture')) {
        rawUser = Map<String, dynamic>.from(res);
      }

      final currentUser = state.user ?? await StorageService.getUser() ?? {};
      final userEmail = (currentUser['email'] ?? rawUser?['email'])
          ?.toString()
          .toLowerCase()
          .trim();
      final userId =
          (currentUser['id'] ??
                  currentUser['_id'] ??
                  rawUser?['id'] ??
                  rawUser?['_id'])
              ?.toString();
      final userName = (currentUser['name'] ?? rawUser?['name'])
          ?.toString()
          .toLowerCase()
          .trim();
      final userPhone = (currentUser['phone'] ?? rawUser?['phone'])
          ?.toString()
          .trim();

      var serverAvatar = extractAvatarUrl(rawUser);

      // If profile API response lacks avatar, search employee list API by email, ID, name, or phone
      if (serverAvatar == null || serverAvatar.isEmpty) {
        try {
          final resMap = await EmployeeService.getAll();
          final rawList =
              resMap['employees'] ??
              resMap['data'] ??
              resMap['records'] ??
              resMap['result'] ??
              resMap['items'];
          if (rawList is List) {
            for (final emp in rawList) {
              if (emp is Map) {
                final empEmail = emp['email']?.toString().toLowerCase().trim();
                final empId = (emp['id'] ?? emp['_id'])?.toString();
                final empName = emp['name']?.toString().toLowerCase().trim();
                final empPhone = emp['phone']?.toString().trim();

                final isMatch =
                    (userEmail != null && empEmail == userEmail) ||
                    (userId != null && empId == userId) ||
                    (userName != null &&
                        empName != null &&
                        empName == userName) ||
                    (userPhone != null &&
                        userPhone.isNotEmpty &&
                        empPhone == userPhone);

                if (isMatch) {
                  final empAvatar = extractAvatarUrl(emp);
                  if (empAvatar != null && empAvatar.isNotEmpty) {
                    serverAvatar = empAvatar;
                    break;
                  }
                }
              }
            }
          }
        } catch (_) {}
      }

      String? cachedAvatar;
      if (userEmail != null && userEmail.isNotEmpty) {
        cachedAvatar = await StorageService.getUserAvatar(userEmail);
      }
      if ((cachedAvatar == null || cachedAvatar.isEmpty) &&
          userId != null &&
          userId.isNotEmpty) {
        cachedAvatar = await StorageService.getUserAvatar(userId);
      }
      if ((cachedAvatar == null || cachedAvatar.isEmpty) &&
          userName != null &&
          userName.isNotEmpty) {
        cachedAvatar = await StorageService.getUserAvatar(userName);
      }

      final existingAvatar = extractAvatarUrl(currentUser) ?? cachedAvatar;
      final avatarToUse = (serverAvatar != null && serverAvatar.isNotEmpty)
          ? serverAvatar
          : (existingAvatar != null && existingAvatar.isNotEmpty
                ? existingAvatar
                : null);

      final userData = Map<String, dynamic>.from(currentUser);
      if (rawUser != null) {
        userData.addAll(rawUser);
      }

      if (avatarToUse != null && avatarToUse.isNotEmpty) {
        userData['avatar'] = avatarToUse;
        userData['profilePicture'] = avatarToUse;
        userData['profileImage'] = avatarToUse;
        userData['profile_picture'] = avatarToUse;
        userData['image'] = avatarToUse;
        userData['avatarUrl'] = avatarToUse;
        userData['photo'] = avatarToUse;

        if (userEmail != null && userEmail.isNotEmpty) {
          await StorageService.saveUserAvatar(userEmail, avatarToUse);
        }
        if (userId != null && userId.isNotEmpty) {
          await StorageService.saveUserAvatar(userId, avatarToUse);
        }
        if (userName != null && userName.isNotEmpty) {
          await StorageService.saveUserAvatar(userName, avatarToUse);
        }
      }

      await StorageService.saveUser(userData);
      state = state.copyWith(user: userData);
    } catch (e) {
      dev.log('[AuthProvider] refreshProfile error: $e', name: 'AuthProvider');
    }
  }

  /// Updates user profile details (Name, Phone, Profile Picture) in DB and local state.
  Future<bool> updateUserProfile({
    required String name,
    String? phone,
    String? profilePicture,
  }) async {
    // Create updated local user map
    final currentMap = Map<String, dynamic>.from(state.user ?? {});

    currentMap['name'] = name;
    if (phone != null) currentMap['phone'] = phone;
    if (profilePicture != null && profilePicture.isNotEmpty) {
      currentMap['avatar'] = profilePicture;
      currentMap['profilePicture'] = profilePicture;
      currentMap['profileImage'] = profilePicture;
      currentMap['profile_picture'] = profilePicture;
      currentMap['image'] = profilePicture;
      currentMap['avatarUrl'] = profilePicture;
      currentMap['photo'] = profilePicture;

      final userEmail =
          (currentMap['email'] ?? currentMap['id'] ?? currentMap['_id'])
              ?.toString();
      final userId = (currentMap['id'] ?? currentMap['_id'])?.toString();
      final userName = currentMap['name']?.toString();

      if (userEmail != null && userEmail.isNotEmpty) {
        await StorageService.saveUserAvatar(userEmail, profilePicture);
      }
      if (userId != null && userId.isNotEmpty) {
        await StorageService.saveUserAvatar(userId, profilePicture);
      }
      if (userName != null && userName.isNotEmpty) {
        await StorageService.saveUserAvatar(userName, profilePicture);
      }
    }

    await StorageService.saveUser(currentMap);
    state = state.copyWith(user: currentMap);

    try {
      final res = await AuthService.updateProfile(
        name: name,
        phone: phone,
        profilePicture: profilePicture,
      );

      // If backend returned raw user object, merge non-null fields
      if (res['data'] is Map<String, dynamic>) {
        final serverMap = Map<String, dynamic>.from(res['data']);
        final existingAvatar = extractAvatarUrl(currentMap);
        if (extractAvatarUrl(serverMap) == null && existingAvatar != null) {
          serverMap['avatar'] = existingAvatar;
          serverMap['profilePicture'] = existingAvatar;
          serverMap['profileImage'] = existingAvatar;
          serverMap['profile_picture'] = existingAvatar;
        }
        currentMap.addAll(serverMap);
      } else if (res['user'] is Map<String, dynamic>) {
        final serverMap = Map<String, dynamic>.from(res['user']);
        final existingAvatar = extractAvatarUrl(currentMap);
        if (extractAvatarUrl(serverMap) == null && existingAvatar != null) {
          serverMap['avatar'] = existingAvatar;
          serverMap['profilePicture'] = existingAvatar;
          serverMap['profileImage'] = existingAvatar;
          serverMap['profile_picture'] = existingAvatar;
        }
        currentMap.addAll(serverMap);
      }

      await StorageService.saveUser(currentMap);
      state = state.copyWith(user: currentMap);

      // Save the avatar we just uploaded so refreshProfile() doesn't wipe it
      final uploadedAvatar = profilePicture;

      await refreshProfile();

      // If refreshProfile() lost our avatar (server didn't return it), restore it
      if (uploadedAvatar != null && uploadedAvatar.isNotEmpty) {
        final afterRefreshAvatar = extractAvatarUrl(state.user);
        if (afterRefreshAvatar == null || afterRefreshAvatar.isEmpty) {
          final restoredMap = Map<String, dynamic>.from(state.user ?? {});
          restoredMap['avatar'] = uploadedAvatar;
          restoredMap['profilePicture'] = uploadedAvatar;
          restoredMap['profileImage'] = uploadedAvatar;
          restoredMap['profile_picture'] = uploadedAvatar;
          restoredMap['image'] = uploadedAvatar;
          restoredMap['avatarUrl'] = uploadedAvatar;
          restoredMap['photo'] = uploadedAvatar;
          await StorageService.saveUser(restoredMap);
          state = state.copyWith(user: restoredMap);
        }
      }

      return true;
    } catch (e) {
      // Offline / backend fallback — local state is already saved!
      return true;
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    if (_ref != null) {
      Future.microtask(() {
        _ref.read(attendanceProvider.notifier).reset();
        _ref.read(employeeProvider.notifier).reset();
      });
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<bool> restoreBiometricSession(Map<String, dynamic> session) async {
    try {
      final token = session['token']?.toString();
      final user = session['user'] as Map<String, dynamic>?;
      final role = session['role']?.toString() ?? 'employee';

      if (token != null && token.isNotEmpty && user != null) {
        await StorageService.saveToken(token);
        await StorageService.saveUser(user);
        await StorageService.saveRole(role);

        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
          role: role,
          token: token,
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> sendForgotPasswordOtp(String email) async {
    try {
      state = state.copyWith(status: AuthStatus.loading, error: null);
      await AuthService.forgotPassword(email);
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return true;
    } catch (e) {
      String msg = 'Failed to send reset code. Please check your email.';
      if (e is DioException) {
        final res = e.response?.data;
        if (res is Map) {
          msg = res['message']?.toString() ?? res['error']?.toString() ?? msg;
        }
        if (e.response?.statusCode == 404 ||
            msg.toLowerCase().contains('route not found') ||
            msg.toLowerCase().contains('not found')) {
          msg =
              'Password reset is not configured on the server. Please contact your administrator.';
        }
      }
      state = state.copyWith(status: AuthStatus.error, error: msg);
      return false;
    }
  }

  Future<bool> resetPasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      state = state.copyWith(status: AuthStatus.loading, error: null);
      await AuthService.resetPassword(
        email: email,
        otp: otp,
        newPassword: newPassword,
      );
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return true;
    } catch (e) {
      String msg = 'Failed to reset password. Invalid OTP or expired code.';
      if (e is DioException) {
        final res = e.response?.data;
        if (res is Map) {
          msg = res['message']?.toString() ?? res['error']?.toString() ?? msg;
        }
        if (e.response?.statusCode == 404 ||
            msg.toLowerCase().contains('route not found') ||
            msg.toLowerCase().contains('not found')) {
          msg =
              'Password reset is not configured on the server. Please contact your administrator.';
        }
      }
      state = state.copyWith(status: AuthStatus.error, error: msg);
      return false;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

import 'dart:developer' as dev;
import 'package:dio/dio.dart';
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
    if (clean.isNotEmpty && clean != 'null' && clean != 'undefined') return clean;
    return null;
  }
  if (avatarOrUser is Map) {
    final fields = [
      'avatar',
      'profilePicture',
      'image',
      'profile_picture',
      'profile_photo',
      'photo',
      'photoUrl',
      'avatarUrl',
      'imageUrl',
      'url',
      'path',
      'picture',
      'img',
      'profile',
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
        refreshProfile();
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
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

      final token = (data['token'] ??
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

      final role = user?['role']?.toString() ??
          (isAdmin ? 'admin' : 'employee');

      if (token != null && token.isNotEmpty) {
        if (user != null) {
          final email = (user['email'] ?? user['id'] ?? user['_id'])?.toString();
          final serverAvatar = (user['avatar'] ??
                  user['profilePicture'] ??
                  user['image'] ??
                  user['avatarUrl'] ??
                  user['photo'] ??
                  user['profile_picture'])
              ?.toString();

          final cachedAvatar = email != null ? await StorageService.getUserAvatar(email) : null;

          final avatarToUse = (serverAvatar != null && serverAvatar.isNotEmpty)
              ? serverAvatar
              : (cachedAvatar != null && cachedAvatar.isNotEmpty ? cachedAvatar : null);

          if (avatarToUse != null && avatarToUse.isNotEmpty) {
            user['avatar'] = avatarToUse;
            user['profilePicture'] = avatarToUse;
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
          errorMsg = 'Cannot connect to server. Please check your internet and try again.';
        } else {
          final resData = e.response?.data;
          if (resData is Map) {
            errorMsg = resData['message']?.toString() ??
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
      final userEmail = (currentUser['email'] ?? rawUser?['email'])?.toString().toLowerCase().trim();
      final userId = (currentUser['id'] ?? currentUser['_id'] ?? rawUser?['id'] ?? rawUser?['_id'])?.toString();

      var serverAvatar = extractAvatarUrl(rawUser);

      // If profile API response lacks avatar, search employee list API
      if ((serverAvatar == null || serverAvatar.isEmpty) && (userEmail != null || userId != null)) {
        try {
          final resMap = await EmployeeService.getAll();
          final rawList = resMap['employees'] ?? resMap['data'] ?? resMap['records'] ?? resMap['result'] ?? resMap['items'];
          if (rawList is List) {
            for (final emp in rawList) {
              if (emp is Map) {
                final empEmail = emp['email']?.toString().toLowerCase().trim();
                final empId = (emp['id'] ?? emp['_id'])?.toString();
                if ((userEmail != null && empEmail == userEmail) || (userId != null && empId == userId)) {
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

      final existingAvatar = extractAvatarUrl(currentUser);
      final avatarToUse = (serverAvatar != null && serverAvatar.isNotEmpty)
          ? serverAvatar
          : (existingAvatar != null && existingAvatar.isNotEmpty ? existingAvatar : null);

      final userData = Map<String, dynamic>.from(currentUser);
      if (rawUser != null) {
        userData.addAll(rawUser);
      }

      if (avatarToUse != null && avatarToUse.isNotEmpty) {
        userData['avatar'] = avatarToUse;
        userData['profilePicture'] = avatarToUse;
        userData['image'] = avatarToUse;
        userData['profile_picture'] = avatarToUse;
        userData['avatarUrl'] = avatarToUse;
        userData['photo'] = avatarToUse;
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
    try {
      final res = await AuthService.updateProfile(
        name: name,
        phone: phone,
        profilePicture: profilePicture,
      );

      // Create updated local user map
      final currentMap = Map<String, dynamic>.from(state.user ?? {});

      // If backend returned raw user object, merge it first
      if (res['data'] is Map<String, dynamic>) {
        currentMap.addAll(Map<String, dynamic>.from(res['data']));
      } else if (res['user'] is Map<String, dynamic>) {
        currentMap.addAll(Map<String, dynamic>.from(res['user']));
      }

      currentMap['name'] = name;
      if (phone != null) currentMap['phone'] = phone;
      if (profilePicture != null && profilePicture.isNotEmpty) {
        currentMap['avatar'] = profilePicture;
        currentMap['profilePicture'] = profilePicture;
        currentMap['image'] = profilePicture;
      }

      await StorageService.saveUser(currentMap);
      state = state.copyWith(user: currentMap);
      await refreshProfile();
      return true;
    } catch (e) {
      // Fallback: local update if offline / API error
      final currentMap = Map<String, dynamic>.from(state.user ?? {});
      currentMap['name'] = name;
      if (phone != null) currentMap['phone'] = phone;
      if (profilePicture != null && profilePicture.isNotEmpty) {
        currentMap['avatar'] = profilePicture;
        currentMap['profilePicture'] = profilePicture;
        currentMap['image'] = profilePicture;
      }
      await StorageService.saveUser(currentMap);
      state = state.copyWith(user: currentMap);
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
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

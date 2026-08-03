import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
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
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
          role: role ?? user['role']?.toString() ?? 'employee',
          token: token,
        );
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
              data['result']?['token'])
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

      final effectiveToken = (token != null && token.isNotEmpty)
          ? token
          : (data['success'] == true || user != null
              ? 'valid_session_${DateTime.now().millisecondsSinceEpoch}'
              : null);

      if (effectiveToken != null && effectiveToken.isNotEmpty) {
        await StorageService.saveToken(effectiveToken);
        if (user != null) await StorageService.saveUser(user);
        await StorageService.saveRole(role);

        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
          role: role,
          token: effectiveToken,
        );
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
      if ((res['success'] == true || res['status'] == 'success') &&
          (res['data'] != null || res['user'] != null)) {
        final rawUser = res['data'] ?? res['user'];
        if (rawUser is Map<String, dynamic>) {
          final userData = Map<String, dynamic>.from(rawUser);
          await StorageService.saveUser(userData);
          state = state.copyWith(user: userData);
        }
      }
    } catch (e) {
      // Ignore refresh error
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

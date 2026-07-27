import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../core/utils/storage_service.dart';

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

  bool get isAdmin => role == 'admin';
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
  AuthNotifier() : super(const AuthState()) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
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

  Future<bool> login(String email, String password,
      {bool isAdmin = false}) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final data = isAdmin
          ? await AuthService.adminLogin(email, password)
          : await AuthService.login(email, password);

      final token = (data['token'] ??
              data['data']?['token'] ??
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
      }

      final role = isAdmin ? 'admin' : (user?['role']?.toString() ?? 'employee');

      if (token != null && token.isNotEmpty) {
        await StorageService.saveToken(token);
        if (user != null) await StorageService.saveUser(user);
        await StorageService.saveRole(role);

        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
          role: role,
          token: token,
        );
        return true;
      }

      final serverMsg =
          data['message'] ?? data['error'] ?? 'Invalid response from server';
      state = state.copyWith(
          status: AuthStatus.error, error: serverMsg.toString());
      return false;
    } catch (e) {
      String errorMsg = 'Login failed. Please check credentials.';
      if (e is DioException) {
        final resData = e.response?.data;
        if (resData is Map) {
          errorMsg = resData['message'] ?? resData['error'] ?? errorMsg;
        } else if (e.message != null && e.message!.isNotEmpty) {
          errorMsg = e.message!;
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
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});


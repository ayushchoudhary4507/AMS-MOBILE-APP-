import '../core/constants/api_constants.dart';
import 'api_service.dart';
import '../core/utils/storage_service.dart';

class AuthService {
  // Employee Login
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final response = await ApiService.post(
      ApiConstants.login,
      data: {'email': email, 'password': password},
    );
    return ApiService.toMap(response.data);
  }

  // Admin Login
  static Future<Map<String, dynamic>> adminLogin(
      String email, String password) async {
    final response = await ApiService.post(
      ApiConstants.adminLogin,
      data: {'email': email, 'password': password},
    );
    return ApiService.toMap(response.data);
  }

  // Register
  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String phone,
  ) async {
    final response = await ApiService.post(
      ApiConstants.register,
      data: {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
      },
    );
    return ApiService.toMap(response.data);
  }

  // Get Profile Settings across all server candidate routes
  static Future<Map<String, dynamic>> getProfile() async {
    final endpoints = [
      '${ApiConstants.settings}/profile',
      '/profile',
      '/employees/me',
      '/employees/profile',
      '/user/profile',
      '/auth/me',
      '/settings',
    ];

    for (final ep in endpoints) {
      try {
        final response = await ApiService.get(ep);
        final map = ApiService.toMap(response.data);
        if (map.isNotEmpty) {
          return map;
        }
      } catch (_) {}
    }
    return {};
  }

  // Update User Profile (Name, Phone, Profile Picture / Avatar)
  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    String? phone,
    String? profilePicture,
  }) async {
    final response = await ApiService.put(
      '${ApiConstants.settings}/profile',
      data: {
        'name': name,
        'phone': ?phone,
        if (profilePicture != null) ...{
          'avatar': profilePicture,
          'profilePicture': profilePicture,
          'image': profilePicture,
        },
      },
    );
    return ApiService.toMap(response.data);
  }

  // Logout
  static Future<void> logout() async {
    await StorageService.clearAll();
  }
}

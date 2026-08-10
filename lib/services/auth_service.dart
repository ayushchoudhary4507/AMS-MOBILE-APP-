import 'package:dio/dio.dart';
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
          'profileImage': profilePicture,
          'profile_picture': profilePicture,
          'image': profilePicture,
        },
      },
    );
    return ApiService.toMap(response.data);
  }

  // Forgot Password: Request OTP / Reset Link
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final candidateEndpoints = [
      '/forgot-password',
      '/auth/forgot-password',
      '/password/forgot',
      '/forgotpassword',
      '/users/forgot-password',
      '/employees/forgot-password',
      '/auth/forgot',
      '/auth/request-otp',
      '/auth/send-otp',
      '/user/forgot-password',
      '/employee/forgot-password',
    ];

    Object? lastError;
    for (final ep in candidateEndpoints) {
      try {
        final response = await ApiService.post(
          ep,
          data: {'email': email.trim()},
        );
        final map = ApiService.toMap(response.data);
        if (map.isNotEmpty || (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300)) {
          return map.isNotEmpty ? map : {'success': true, 'message': 'Reset code sent successfully'};
        }
      } catch (e) {
        if (e is DioException) {
          final status = e.response?.statusCode;
          // If the endpoint actually exists and returned a non-404 error (e.g. 400 Bad Request, 422 Unprocessable Entity),
          // stop checking candidates and rethrow the actual backend response.
          if (status != null && status != 404) {
            rethrow;
          }
        }
        lastError = e;
      }
    }

    if (lastError != null) throw lastError;
    return {};
  }

  // Reset Password: Send OTP/Token and New Password
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final candidateEndpoints = [
      '/reset-password',
      '/auth/reset-password',
      '/password/reset',
      '/resetpassword',
      '/users/reset-password',
      '/employees/reset-password',
      '/auth/verify-otp',
      '/auth/reset',
      '/user/reset-password',
      '/employee/reset-password',
    ];

    Object? lastError;
    for (final ep in candidateEndpoints) {
      try {
        final response = await ApiService.post(
          ep,
          data: {
            'email': email.trim(),
            'otp': otp.trim(),
            'token': otp.trim(),
            'code': otp.trim(),
            'password': newPassword.trim(),
            'newPassword': newPassword.trim(),
          },
        );
        final map = ApiService.toMap(response.data);
        if (map.isNotEmpty || (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300)) {
          return map.isNotEmpty ? map : {'success': true, 'message': 'Password reset successfully'};
        }
      } catch (e) {
        if (e is DioException) {
          final status = e.response?.statusCode;
          if (status != null && status != 404) {
            rethrow;
          }
        }
        lastError = e;
      }
    }

    if (lastError != null) throw lastError;
    return {};
  }

  // Logout
  static Future<void> logout() async {
    await StorageService.clearAll();
  }
}


import 'dart:io';
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
    dynamic payload;

    if (profilePicture != null && profilePicture.isNotEmpty) {
      final cleanPath = profilePicture.replaceFirst('file://', '');
      final file = File(cleanPath);
      if (file.existsSync()) {
        final formData = FormData.fromMap({
          'name': name,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          'profileImage': await MultipartFile.fromFile(
            file.path,
            filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        });
        payload = formData;
      }
    }

    payload ??= {
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (profilePicture != null) ...{
        'avatar': profilePicture,
        'profilePicture': profilePicture,
        'profileImage': profilePicture,
        'profile_picture': profilePicture,
        'image': profilePicture,
      },
    };

    final response = await ApiService.put(
      '${ApiConstants.settings}/profile',
      data: payload,
    );
    return ApiService.toMap(response.data);
  }

  // Forgot Password: Request OTP to Phone or Email in Real-Time
  static Future<Map<String, dynamic>> forgotPassword(String identifier) async {
    final raw = identifier.trim();
    final isEmail = raw.contains('@');

    // Clean phone digits (e.g. 10-digit number without spaces or +91 prefix)
    String cleanMobile = raw.replaceAll(RegExp(r'\D'), '');
    if (cleanMobile.length > 10 && cleanMobile.startsWith('91')) {
      cleanMobile = cleanMobile.substring(2);
    }

    final payload = isEmail
        ? {'email': raw}
        : {'mobile': cleanMobile, 'phone': cleanMobile};

    try {
      final response = await ApiService.post(
        '/auth/send',
        data: payload,
      );
      final map = ApiService.toMap(response.data);

      if (map['success'] == false) {
        final msg = map['message']?.toString() ?? 'Failed to send OTP code.';
        if (msg.toLowerCase().contains('user not found')) {
          throw Exception(
              'No account found with this ${isEmail ? "email address" : "phone number"}. Please register or check your details.');
        }
        if (msg.toLowerCase().contains('failed to send otp email') ||
            msg.toLowerCase().contains('email configuration') ||
            msg.toLowerCase().contains('timeout') ||
            msg.toLowerCase().contains('connection') ||
            msg.toLowerCase().contains('smtp') ||
            isEmail) {
          throw Exception(
              'Backend email server (SMTP) is not configured. Please use "Phone SMS" option to receive your OTP.');
        }
        throw Exception(msg);
      }

      return map.isNotEmpty
          ? map
          : {
              'success': true,
              'message':
                  'OTP sent successfully to ${isEmail ? raw : cleanMobile}',
            };
    } catch (e) {
      if (e is DioException) {
        final errData = e.response?.data;
        if (errData is Map && errData['message'] != null) {
          final msg = errData['message'].toString();
          if (msg.toLowerCase().contains('user not found')) {
            throw Exception(
                'No account found with this ${isEmail ? "email address" : "phone number"}. Please register or check your details.');
          }
          if (msg.toLowerCase().contains('failed to send otp email') ||
              msg.toLowerCase().contains('email configuration') ||
              msg.toLowerCase().contains('timeout') ||
              msg.toLowerCase().contains('connection') ||
              msg.toLowerCase().contains('smtp') ||
              isEmail) {
            throw Exception(
                'Backend email server (SMTP) is not configured. Please use "Phone SMS" option to receive your OTP.');
          }
          throw Exception(msg);
        }
      }
      rethrow;
    }
  }

  // Reset Password: Send Real OTP and New Password to Backend
  static Future<Map<String, dynamic>> resetPassword({
    required String identifier,
    required String otp,
    required String newPassword,
  }) async {
    final raw = identifier.trim();
    final isEmail = raw.contains('@');

    String cleanMobile = raw.replaceAll(RegExp(r'\D'), '');
    if (cleanMobile.length > 10 && cleanMobile.startsWith('91')) {
      cleanMobile = cleanMobile.substring(2);
    }

    final payload = {
      if (isEmail) 'email': raw,
      if (!isEmail) ...{
        'mobile': cleanMobile,
        'phone': cleanMobile,
      },
      'otp': otp.trim(),
      'password': newPassword.trim(),
      'newPassword': newPassword.trim(),
    };

    try {
      final response = await ApiService.post(
        '/auth/verify',
        data: payload,
      );
      final map = ApiService.toMap(response.data);

      if (map['success'] == false) {
        final msg = map['message']?.toString() ?? 'Invalid OTP code.';
        throw Exception(msg);
      }

      return map.isNotEmpty
          ? map
          : {'success': true, 'message': 'Password reset successfully'};
    } catch (e) {
      if (e is DioException) {
        final errData = e.response?.data;
        if (errData is Map && errData['message'] != null) {
          final msg = errData['message'].toString();
          if (msg.toLowerCase().contains('invalid otp')) {
            throw Exception('Invalid OTP code. Please enter the 6-digit code received on your phone.');
          }
          throw Exception(msg);
        }
      }
      rethrow;
    }
  }

  // Logout
  static Future<void> logout() async {
    await StorageService.clearAll();
  }
}


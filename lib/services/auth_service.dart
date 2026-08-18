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
  // Cache last successfully matched identifier format (e.g. +919876543210 vs 9876543210)
  static String? _lastMatchedIdentifier;

  // Forgot Password: Request OTP to Phone or Email with multi-format matching
  static Future<Map<String, dynamic>> forgotPassword(String identifier) async {
    final raw = identifier.trim();
    final isEmail = raw.contains('@');

    if (isEmail) {
      final payload = {'email': raw.toLowerCase()};
      try {
        final response = await ApiService.post('/auth/send', data: payload);
        final map = ApiService.toMap(response.data);
        if (map['success'] == false) {
          final msg = map['message']?.toString() ?? 'Failed to send OTP code.';
          if (msg.toLowerCase().contains('user not found') ||
              msg.toLowerCase().contains('no account found') ||
              msg.toLowerCase().contains('not found')) {
            throw Exception('No account found for "$raw". Please check your registered email or contact Admin.');
          }
          throw Exception(msg);
        }
        _lastMatchedIdentifier = raw;
        return map.isNotEmpty ? map : {'success': true, 'message': 'OTP sent successfully to $raw'};
      } catch (e) {
        if (e is DioException) {
          final errData = e.response?.data;
          if (errData is Map && errData['message'] != null) {
            final msg = errData['message'].toString();
            if (msg.toLowerCase().contains('user not found') ||
                msg.toLowerCase().contains('no account found') ||
                msg.toLowerCase().contains('not found')) {
              throw Exception('No account found for "$raw". Please check your registered email or contact Admin.');
            }
            throw Exception(msg);
          }
        }
        rethrow;
      }
    }

    // Phone / Mobile Mode: Build candidates to match however the phone number was stored in MongoDB (+91, 10-digit, etc.)
    final allDigits = raw.replaceAll(RegExp(r'\D'), '');
    String clean10 = allDigits;
    if (clean10.length > 10 && clean10.startsWith('91')) {
      clean10 = clean10.substring(2);
    }
    if (clean10.length > 10) {
      clean10 = clean10.substring(clean10.length - 10);
    }

    final candidates = <String>{};
    if (raw.isNotEmpty) candidates.add(raw);
    if (clean10.isNotEmpty) {
      candidates.add(clean10);
      candidates.add('+91$clean10');
      candidates.add('91$clean10');
    }

    Exception? lastError;

    for (final candidate in candidates) {
      try {
        final payload = {'mobile': candidate, 'phone': candidate};
        final response = await ApiService.post('/auth/send', data: payload);
        final map = ApiService.toMap(response.data);

        if (map['success'] == true || (map['status'] == 'success') || (response.statusCode == 200)) {
          _lastMatchedIdentifier = candidate;
          return map.isNotEmpty
              ? map
              : {
                  'success': true,
                  'message': 'OTP sent successfully to $candidate',
                };
        }

        final msg = map['message']?.toString() ?? '';
        if (!msg.toLowerCase().contains('user not found')) {
          throw Exception(msg.isNotEmpty ? msg : 'Failed to send OTP to $candidate');
        }
      } catch (e) {
        if (e is DioException) {
          final errData = e.response?.data;
          final status = e.response?.statusCode;
          final msg = errData is Map ? (errData['message']?.toString() ?? '') : '';

          // If 404 (User not found), try next candidate format
          if (status == 404 ||
              msg.toLowerCase().contains('user not found') ||
              msg.toLowerCase().contains('no account found') ||
              msg.toLowerCase().contains('not found')) {
            lastError = Exception('No account found for "$raw". Please check your registered number or contact Admin.');
            continue;
          }

          if (msg.isNotEmpty) {
            throw Exception(msg);
          }
        } else if (e is Exception) {
          final str = e.toString();
          if (str.toLowerCase().contains('user not found') ||
              str.toLowerCase().contains('no account found') ||
              str.toLowerCase().contains('not found')) {
            lastError = Exception('No account found for "$raw". Please check your registered number or contact Admin.');
            continue;
          }
          rethrow;
        }
        lastError = e is Exception ? e : Exception(e.toString());
      }
    }

    throw lastError ??
        Exception('No account found with phone number ($raw). Please check your registered number or contact Admin.');
  }

  // Reset Password: Send Real OTP and New Password to Backend
  static Future<Map<String, dynamic>> resetPassword({
    required String identifier,
    required String otp,
    required String newPassword,
  }) async {
    final raw = identifier.trim();
    final isEmail = raw.contains('@');
    final effectivePhone = _lastMatchedIdentifier ?? raw;

    final payload = {
      if (isEmail) 'email': raw,
      if (!isEmail) ...{
        'mobile': effectivePhone,
        'phone': effectivePhone,
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
            throw Exception('Invalid OTP code. Please enter the 6-digit code received on your ${isEmail ? "Gmail / email" : "phone"}.');
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


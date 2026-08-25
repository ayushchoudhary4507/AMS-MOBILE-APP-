import 'dart:convert';
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

  // Send Login OTP to Email
  static Future<Map<String, dynamic>> sendLoginOtp(String email) async {
    final clean = email.trim().toLowerCase();
    final response = await ApiService.post(
      ApiConstants.authSend,
      data: {'email': clean},
    );
    final map = ApiService.toMap(response.data);
    if (map['success'] == false) {
      throw Exception(map['message']?.toString() ?? 'Failed to send OTP to $clean');
    }
    return map;
  }

  // Verify Login OTP and authenticate
  static Future<Map<String, dynamic>> verifyLoginOtp(
      String email, String otp) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanOtp = otp.trim();
    final response = await ApiService.post(
      ApiConstants.authVerify,
      data: {
        'email': cleanEmail,
        'otp': cleanOtp,
      },
    );
    final map = ApiService.toMap(response.data);
    if (map['success'] == false) {
      throw Exception(map['message']?.toString() ?? 'Invalid or expired OTP code.');
    }
    return map;
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
  // Preserves existing photo persistently in MongoDB Atlas via Base64 Data URI & multipart
  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    String? phone,
    String? profilePicture,
    String? userId,
  }) async {
    dynamic payload;
    String? base64DataUri;

    if (profilePicture != null && profilePicture.isNotEmpty) {
      final cleanPath = profilePicture.replaceFirst('file://', '');
      final file = File(cleanPath);
      if (file.existsSync()) {
        try {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            base64DataUri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          }
        } catch (_) {}

        final formMap = <String, dynamic>{
          'name': name,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          'profileImage': await MultipartFile.fromFile(
            file.path,
            filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        };
        if (base64DataUri != null) {
          formMap['avatar'] = base64DataUri;
          formMap['profilePicture'] = base64DataUri;
          formMap['photo'] = base64DataUri;
          formMap['image'] = base64DataUri;
          formMap['profile_picture'] = base64DataUri;
        }
        payload = FormData.fromMap(formMap);
      }
    }

    final avatarVal = base64DataUri ?? profilePicture;

    payload ??= {
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (avatarVal != null && avatarVal.isNotEmpty) ...{
        'avatar': avatarVal,
        'profilePicture': avatarVal,
        'profileImage': avatarVal,
        'profile_picture': avatarVal,
        'image': avatarVal,
        'photo': avatarVal,
      },
    };

    Map<String, dynamic> result = {};

    // 1. Update /settings/profile
    try {
      final response = await ApiService.put(
        '${ApiConstants.settings}/profile',
        data: payload,
      );
      result = ApiService.toMap(response.data);
    } catch (_) {}

    // 2. Sync to employee and user records so Web Admin & MongoDB retain the photo permanently
    final syncData = <String, dynamic>{
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (avatarVal != null && avatarVal.isNotEmpty) ...{
        'avatar': avatarVal,
        'profilePicture': avatarVal,
        'profileImage': avatarVal,
        'profile_picture': avatarVal,
        'image': avatarVal,
        'photo': avatarVal,
      },
    };

    final candidateEndpoints = [
      if (userId != null && userId.isNotEmpty) '${ApiConstants.employees}/$userId',
      '/employees/profile',
      '/user/profile',
      '/auth/profile',
    ];

    for (final ep in candidateEndpoints) {
      try {
        final res = await ApiService.put(ep, data: syncData);
        final map = ApiService.toMap(res.data);
        if (map.isNotEmpty && result.isEmpty) {
          result = map;
        }
      } catch (_) {}
    }

    return result.isNotEmpty ? result : {'success': true};
  }

  // Forgot Password: Request OTP to Phone or Email via Backend API
  static String? _lastMatchedIdentifier;

  static Future<Map<String, dynamic>> forgotPassword(String identifier) async {
    final raw = identifier.trim();
    final isEmail = raw.contains('@');

    if (isEmail) {
      final payload = {'email': raw.toLowerCase()};

      // Debug logs as requested
      // ignore: avoid_print
      print('================ [FORGOT PASSWORD API REQUEST] ================');
      // ignore: avoid_print
      print('Full Request URL: ${ApiConstants.baseUrl}${ApiConstants.authSend}');
      // ignore: avoid_print
      print('HTTP Method: POST');
      // ignore: avoid_print
      print('Request Headers: { Content-Type: application/json, Accept: application/json }');
      // ignore: avoid_print
      print('Request Payload: $payload');

      try {
        final response = await ApiService.post(
          ApiConstants.authSend,
          data: payload,
        );

        // ignore: avoid_print
        print('================ [FORGOT PASSWORD API RESPONSE] ===============');
        // ignore: avoid_print
        print('Response Status Code: ${response.statusCode}');
        // ignore: avoid_print
        print('Response Body: ${response.data}');

        final map = ApiService.toMap(response.data);
        if (map['success'] == true || (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300)) {
          _lastMatchedIdentifier = raw;
          return map.isNotEmpty
              ? map
              : {
                  'success': true,
                  'message': 'OTP sent successfully to $raw',
                };
        }

        final msg = map['message']?.toString() ?? 'Failed to send OTP to $raw';
        throw Exception(msg);
      } catch (e) {
        // ignore: avoid_print
        print('================ [FORGOT PASSWORD API ERROR] ==================');
        // ignore: avoid_print
        print('Network/API Error: $e');
        if (e is DioException) {
          // ignore: avoid_print
          print('Dio Status Code: ${e.response?.statusCode}');
          // ignore: avoid_print
          print('Dio Response Body: ${e.response?.data}');
          final errData = e.response?.data;
          final msg = (errData is Map)
              ? (errData['message']?.toString() ?? errData['error']?.toString() ?? '')
              : (errData is String ? errData : '');
          if (msg.isNotEmpty) {
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

        // ignore: avoid_print
        print('================ [FORGOT PASSWORD API REQUEST (PHONE)] ========');
        // ignore: avoid_print
        print('Full Request URL: ${ApiConstants.baseUrl}${ApiConstants.authSend}');
        // ignore: avoid_print
        print('HTTP Method: POST');
        // ignore: avoid_print
        print('Request Payload: $payload');

        final response = await ApiService.post(ApiConstants.authSend, data: payload);

        // ignore: avoid_print
        print('================ [FORGOT PASSWORD API RESPONSE (PHONE)] =======');
        // ignore: avoid_print
        print('Response Status Code: ${response.statusCode}');
        // ignore: avoid_print
        print('Response Body: ${response.data}');

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
        // ignore: avoid_print
        print('================ [FORGOT PASSWORD PHONE ERROR] ================');
        // ignore: avoid_print
        print('Error candidate ($candidate): $e');
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

  // Reset Password: Send Real OTP and New Password to Backend (POST /auth/verify)
  static Future<Map<String, dynamic>> resetPassword({
    required String identifier,
    required String otp,
    required String newPassword,
  }) async {
    final raw = identifier.trim();
    final isEmail = raw.contains('@');
    final effectivePhone = _lastMatchedIdentifier ?? raw;

    final payload = {
      if (isEmail) 'email': raw.toLowerCase(),
      if (!isEmail) ...{
        'mobile': effectivePhone,
        'phone': effectivePhone,
      },
      'otp': otp.trim(),
      'password': newPassword.trim(),
      'newPassword': newPassword.trim(),
    };

    // Debug logs (passwords safely masked)
    // ignore: avoid_print
    print('================ [RESET PASSWORD API REQUEST] =================');
    // ignore: avoid_print
    print('Full Request URL: ${ApiConstants.baseUrl}${ApiConstants.authVerify}');
    // ignore: avoid_print
    print('HTTP Method: POST');
    // ignore: avoid_print
    print('Request Headers: { Content-Type: application/json, Accept: application/json }');
    // ignore: avoid_print
    print('Request Payload: { ${isEmail ? "email: ${raw.toLowerCase()}" : "mobile: $effectivePhone"}, otp: ${otp.trim()}, password: [MASKED], newPassword: [MASKED] }');

    try {
      final response = await ApiService.post(
        ApiConstants.authVerify,
        data: payload,
      );

      // ignore: avoid_print
      print('================ [RESET PASSWORD API RESPONSE] ================');
      // ignore: avoid_print
      print('Response Status Code: ${response.statusCode}');
      // ignore: avoid_print
      print('Response Body: ${response.data}');

      final map = ApiService.toMap(response.data);

      if (map['success'] == false) {
        final msg = map['message']?.toString() ?? 'Invalid OTP code.';
        throw Exception(msg);
      }

      return map.isNotEmpty
          ? map
          : {'success': true, 'message': 'Password reset successfully'};
    } catch (e) {
      // ignore: avoid_print
      print('================ [RESET PASSWORD API ERROR] ===================');
      // ignore: avoid_print
      print('Network/API Error: $e');
      if (e is DioException) {
        // ignore: avoid_print
        print('Dio Status Code: ${e.response?.statusCode}');
        // ignore: avoid_print
        print('Dio Response Body: ${e.response?.data}');
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


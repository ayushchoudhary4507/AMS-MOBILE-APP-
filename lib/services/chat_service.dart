import 'dart:io';
import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import 'api_service.dart';

class ChatService {
  /// Fetch all users available for chat
  static Future<Map<String, dynamic>> getUsers() async {
    try {
      final response = await ApiService.dio.get(
        '${ApiConstants.baseUrl}/messages/users',
      );
      return response.data is Map<String, dynamic>
          ? response.data
          : {'success': true, 'users': response.data};
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch users', 'users': []};
    }
  }

  /// Fetch all conversations with last message and unread count
  static Future<Map<String, dynamic>> getConversations() async {
    try {
      final response = await ApiService.dio.get(
        '${ApiConstants.baseUrl}/messages/conversations',
      );
      return response.data is Map<String, dynamic>
          ? response.data
          : {'success': true, 'conversations': response.data};
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch conversations', 'conversations': []};
    }
  }

  /// Fetch chat history with a specific user
  static Future<Map<String, dynamic>> getMessages(String userId) async {
    try {
      final response = await ApiService.dio.get(
        '${ApiConstants.baseUrl}/messages/$userId',
      );
      return response.data is Map<String, dynamic>
          ? response.data
          : {'success': true, 'messages': response.data};
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch messages', 'messages': []};
    }
  }

  /// Send a message (text or media attachment)
  static Future<Map<String, dynamic>> sendMessage({
    required String receiverId,
    required String message,
    String messageType = 'text',
    String? fileUrl,
    String? fileName,
    String? fileType,
  }) async {
    try {
      final response = await ApiService.dio.post(
        '${ApiConstants.baseUrl}/messages',
        data: {
          'receiverId': receiverId,
          'message': message,
          'messageType': messageType,
          'fileUrl': fileUrl ?? '',
          'fileName': fileName ?? '',
          'fileType': fileType ?? '',
        },
      );
      return response.data is Map<String, dynamic>
          ? response.data
          : {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'message': 'Failed to send message'};
    }
  }

  /// Mark all messages from a specific user as read
  static Future<Map<String, dynamic>> markAsRead(String userId) async {
    try {
      final response = await ApiService.dio.put(
        '${ApiConstants.baseUrl}/messages/read/$userId',
      );
      return response.data is Map<String, dynamic>
          ? response.data
          : {'success': true};
    } catch (e) {
      return {'success': false};
    }
  }

  /// Get total unread message count
  static Future<Map<String, dynamic>> getUnreadCount() async {
    try {
      final response = await ApiService.dio.get(
        '${ApiConstants.baseUrl}/messages/unread-count',
      );
      return response.data is Map<String, dynamic>
          ? response.data
          : {'success': true, 'totalUnread': 0};
    } catch (e) {
      return {'success': false, 'totalUnread': 0};
    }
  }

  /// Upload file attachment (Image / PDF / File)
  static Future<Map<String, dynamic>> uploadFile(File file) async {
    try {
      final fileName = file.path.split('/').last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });

      final response = await ApiService.dio.post(
        '${ApiConstants.baseUrl}/messages/upload',
        data: formData,
      );
      return response.data is Map<String, dynamic>
          ? response.data
          : {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'message': 'Failed to upload file'};
    }
  }
}

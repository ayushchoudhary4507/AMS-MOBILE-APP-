import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/face_attendance_record_model.dart';

/// Service managing persistent storage and retrieval of Face Lock attendance records
/// and captured face photos for Admin viewing.
class FaceAttendanceLogService {
  static final FaceAttendanceLogService _instance =
      FaceAttendanceLogService._internal();
  factory FaceAttendanceLogService() => _instance;
  FaceAttendanceLogService._internal();

  static const String _keyFaceLogs = 'ams_face_attendance_logs_v1';
  static const String _keyRegisteredFacePrefix = 'ams_reg_face_img_';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Compresses raw camera image bytes into a compact base64 JPEG thumbnail
  /// Suitable for fast local storage and instant UI rendering without lag.
  static String? compressImageToBase64(
    Uint8List imageBytes, {
    int targetWidth = 280,
    int quality = 82,
  }) {
    try {
      final originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) return null;

      // Maintain aspect ratio while resizing
      final img.Image resizedImage;
      if (originalImage.width > targetWidth) {
        resizedImage = img.copyResize(
          originalImage,
          width: targetWidth,
          interpolation: img.Interpolation.linear,
        );
      } else {
        resizedImage = originalImage;
      }

      // Encode as optimized JPEG
      final jpegBytes = img.encodeJpg(resizedImage, quality: quality);
      return base64Encode(jpegBytes);
    } catch (e) {
      dev.log('[FaceAttendanceLogService] Error compressing face image: $e',
          name: 'FaceAttendanceLog');
      return null;
    }
  }

  /// Saves a new Face Attendance Record into persistent storage.
  Future<bool> saveFaceAttendanceLog(FaceAttendanceRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = await getFaceAttendanceLogs();

      // Avoid exact duplicate entries within 30 seconds for the same user
      logs.removeWhere((existing) =>
          existing.userId == record.userId &&
          existing.timestamp.difference(record.timestamp).abs().inSeconds < 30);

      // Insert newest at the beginning
      logs.insert(0, record);

      // Keep maximum 200 recent records to keep storage nimble
      final trimmedLogs = logs.take(200).toList();

      final encodedList =
          jsonEncode(trimmedLogs.map((e) => e.toJson()).toList());
      await prefs.setString(_keyFaceLogs, encodedList);

      dev.log(
        '[FaceAttendanceLogService] Saved face attendance log for ${record.userName} (ID: ${record.userId}) at ${record.formattedDateTime}',
        name: 'FaceAttendanceLog',
      );
      return true;
    } catch (e) {
      dev.log(
        '[FaceAttendanceLogService] Error saving face attendance log: $e',
        name: 'FaceAttendanceLog',
      );
      return false;
    }
  }

  /// Retrieves all Face Attendance Records, sorted newest first.
  Future<List<FaceAttendanceRecord>> getFaceAttendanceLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyFaceLogs);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) =>
                FaceAttendanceRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      dev.log(
        '[FaceAttendanceLogService] Error loading face attendance logs: $e',
        name: 'FaceAttendanceLog',
      );
    }
    return [];
  }

  /// Retrieves Face Attendance Records filtered for a specific date.
  Future<List<FaceAttendanceRecord>> getFaceAttendanceLogsByDate(
      DateTime targetDate) async {
    final allLogs = await getFaceAttendanceLogs();
    return allLogs.where((log) {
      return log.timestamp.year == targetDate.year &&
          log.timestamp.month == targetDate.month &&
          log.timestamp.day == targetDate.day;
    }).toList();
  }

  /// Saves enrolled face reference image for an employee during Face Lock Registration.
  Future<bool> saveRegisteredFaceImage({
    required String userId,
    required String imageBase64,
  }) async {
    try {
      final cleanId = userId.trim();
      if (cleanId.isEmpty || imageBase64.isEmpty) return false;

      await _secureStorage.write(
        key: '$_keyRegisteredFacePrefix$cleanId',
        value: imageBase64,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_keyRegisteredFacePrefix$cleanId', imageBase64);

      dev.log(
        '[FaceAttendanceLogService] Saved registered face photo for user $cleanId',
        name: 'FaceAttendanceLog',
      );
      return true;
    } catch (e) {
      dev.log(
        '[FaceAttendanceLogService] Error saving registered face photo: $e',
        name: 'FaceAttendanceLog',
      );
      return false;
    }
  }

  /// Retrieves enrolled face reference image for a specific user ID.
  Future<String?> getRegisteredFaceImage(String userId) async {
    try {
      final cleanId = userId.trim();
      if (cleanId.isEmpty) return null;

      String? img = await _secureStorage.read(
        key: '$_keyRegisteredFacePrefix$cleanId',
      );

      if (img == null || img.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        img = prefs.getString('$_keyRegisteredFacePrefix$cleanId');
      }

      return img;
    } catch (e) {
      dev.log(
        '[FaceAttendanceLogService] Error getting registered face image: $e',
        name: 'FaceAttendanceLog',
      );
      return null;
    }
  }

  /// Deletes a specific face attendance record by ID.
  Future<bool> deleteFaceAttendanceLog(String logId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = await getFaceAttendanceLogs();
      logs.removeWhere((item) => item.id == logId);

      final encodedList = jsonEncode(logs.map((e) => e.toJson()).toList());
      await prefs.setString(_keyFaceLogs, encodedList);
      return true;
    } catch (e) {
      dev.log('[FaceAttendanceLogService] Error deleting log: $e',
          name: 'FaceAttendanceLog');
      return false;
    }
  }

  /// Clears all stored face attendance records (Admin utility).
  Future<bool> clearAllFaceLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFaceLogs);
      return true;
    } catch (e) {
      dev.log('[FaceAttendanceLogService] Error clearing logs: $e',
          name: 'FaceAttendanceLog');
      return false;
    }
  }
}

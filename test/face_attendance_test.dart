import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ams_mobile_app/models/attendance_model.dart';
import 'package:ams_mobile_app/services/face_recognition_service.dart';

void main() {
  group('Face Attendance Tests', () {
    final faceService = FaceRecognitionService();

    test('AttendanceModel parses attendance with attendanceMethod correctly', () {
      final json = {
        '_id': 'att_face_001',
        'employeeId': 'emp_123',
        'status': 'present',
        'checkIn': '2026-08-18T09:00:00.000Z',
        'workingHours': 8.0,
        'notes': 'Face Lock Verified',
        'attendanceMethod': 'FACE',
      };

      final model = AttendanceModel.fromJson(json);
      expect(model.id, equals('att_face_001'));
      expect(model.status, equals('present'));
      expect(model.isCheckedIn, isTrue);
      expect(model.notes, contains('Face Lock Verified'));
    });

    test('Enrolled employee face vector matches with score >= security threshold', () {
      final image1 = img.Image(width: 120, height: 120);
      img.fill(image1, color: img.ColorRgb8(210, 160, 130));
      for (int y = 30; y < 90; y++) {
        for (int x = 30; x < 90; x++) {
          image1.setPixelRgba(x, y, x * 2, y * 2, 120, 255);
        }
      }
      final bytes1 = img.encodeJpg(image1);
      final embedding1 = faceService.extractFaceEmbeddingFromBytes(bytes1)!;

      final result = faceService.verifyFaceVector(embedding1, embedding1);
      expect(result.isSuccess, isTrue);
      expect(result.status, equals(FaceVerificationStatus.matched));
      expect(result.similarityScore, greaterThanOrEqualTo(FaceRecognitionService.securityThreshold));
    });

    test('Different employee face vector is rejected with score < security threshold', () {
      final imageA = img.Image(width: 120, height: 120);
      img.fill(imageA, color: img.ColorRgb8(220, 180, 140)); // Employee A
      for (int y = 0; y < 120; y++) {
        for (int x = 0; x < 120; x++) {
          if (x % 4 == 0) imageA.setPixelRgba(x, y, 100, 50, 40, 255);
        }
      }

      final imageB = img.Image(width: 120, height: 120);
      img.fill(imageB, color: img.ColorRgb8(80, 60, 50)); // Employee B (different structure)
      for (int y = 0; y < 120; y++) {
        for (int x = 0; x < 120; x++) {
          if (y % 4 == 0) imageB.setPixelRgba(x, y, 200, 220, 240, 255);
        }
      }

      final embeddingA = faceService.extractFaceEmbeddingFromBytes(img.encodeJpg(imageA))!;
      final embeddingB = faceService.extractFaceEmbeddingFromBytes(img.encodeJpg(imageB))!;

      final result = faceService.verifyFaceVector(embeddingB, embeddingA);
      expect(result.isSuccess, isFalse);
      expect(result.status, equals(FaceVerificationStatus.notRecognized));
      expect(result.similarityScore, lessThan(FaceRecognitionService.securityThreshold));
    });
  });
}

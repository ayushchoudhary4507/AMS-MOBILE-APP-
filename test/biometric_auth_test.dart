import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:local_auth/local_auth.dart';
import 'package:ams_mobile_app/services/biometric_service.dart';
import 'package:ams_mobile_app/services/face_recognition_service.dart';
import 'package:ams_mobile_app/providers/biometric_provider.dart';

void main() {
  group('BiometricCapabilities Tests', () {
    test('Default BiometricCapabilities has all disabled/false flags', () {
      const caps = BiometricCapabilities();
      expect(caps.isSupported, isFalse);
      expect(caps.canCheckBiometrics, isFalse);
      expect(caps.hasEnrolledBiometrics, isFalse);
      expect(caps.hasFingerprint, isFalse);
      expect(caps.hasFace, isFalse);
      expect(caps.isBiometricEnabled, isFalse);
      expect(caps.isFingerprintEnabled, isFalse);
      expect(caps.isFaceLockEnabled, isFalse);
      expect(caps.isAvailable, isFalse);
    });

    test('isAvailable is true ONLY when supported, can check, AND enrolled', () {
      const notEnrolled = BiometricCapabilities(
        isSupported: true,
        canCheckBiometrics: true,
        hasEnrolledBiometrics: false,
      );
      expect(notEnrolled.isAvailable, isFalse);

      const enrolled = BiometricCapabilities(
        isSupported: true,
        canCheckBiometrics: true,
        hasEnrolledBiometrics: true,
        availableTypes: [BiometricType.face],
      );
      expect(enrolled.isAvailable, isTrue);
    });

    test('BiometricCapabilities correctly reflects Face Lock capability', () {
      const faceCaps = BiometricCapabilities(
        isSupported: true,
        canCheckBiometrics: true,
        hasEnrolledBiometrics: true,
        hasFace: true,
        isFaceLockEnabled: true,
        availableTypes: [BiometricType.face],
      );
      expect(faceCaps.hasFace, isTrue);
      expect(faceCaps.hasFaceId, isTrue);
      expect(faceCaps.isFaceLockEnabled, isTrue);
    });
  });

  group('BiometricAuthResult Tests', () {
    test('BiometricAuthResult.success creates authenticated result without error', () {
      final res = BiometricAuthResult.success();
      expect(res.authenticated, isTrue);
      expect(res.errorMessage, isNull);
    });

    test('BiometricAuthResult.failure creates unauthenticated result with error message', () {
      final res = BiometricAuthResult.failure('Face not recognized. Please try again.');
      expect(res.authenticated, isFalse);
      expect(res.errorMessage, equals('Face not recognized. Please try again.'));
    });
  });

  group('BiometricState Tests', () {
    test('BiometricState copyWith works properly', () {
      const state = BiometricState();
      expect(state.isAuthenticating, isFalse);
      expect(state.errorMessage, isNull);

      final updated = state.copyWith(
        isAuthenticating: true,
        errorMessage: 'Face not recognized. Please try again.',
      );
      expect(updated.isAuthenticating, isTrue);
      expect(updated.errorMessage, equals('Face not recognized. Please try again.'));
    });
  });

  group('FaceRecognitionService Image Embedding Tests', () {
    final faceService = FaceRecognitionService();

    test('Identical vectors produce cosine similarity of 1.0', () {
      final v1 = [0.5, 0.5, 0.5, 0.5];
      final similarity = faceService.calculateCosineSimilarity(v1, v1);
      expect(similarity, closeTo(1.0, 0.001));
    });

    test('Orthogonal / different vectors produce low similarity', () {
      final v1 = [1.0, 0.0, 0.0, 0.0];
      final v2 = [0.0, 1.0, 0.0, 0.0];
      final similarity = faceService.calculateCosineSimilarity(v1, v2);
      expect(similarity, closeTo(0.0, 0.001));
    });

    test('extractFaceEmbeddingFromBytes generates 224-dimensional embedding from image bytes', () {
      final image = img.Image(width: 120, height: 120);
      img.fill(image, color: img.ColorRgb8(200, 150, 120)); // Skin tone simulation
      for (int y = 30; y < 90; y++) {
        for (int x = 30; x < 90; x++) {
          image.setPixelRgba(x, y, x * 2, y * 2, 100, 255);
        }
      }
      final bytes = img.encodeJpg(image);

      final embedding = faceService.extractFaceEmbeddingFromBytes(bytes);
      expect(embedding, isNotNull);
      expect(embedding!.length, equals(224));
    });

    test('Comparing same image embedding succeeds with score > threshold', () {
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

    test('Comparing different person image embedding is rejected with status notRecognized', () {
      final imageA = img.Image(width: 120, height: 120);
      img.fill(imageA, color: img.ColorRgb8(220, 180, 140)); // Person A
      for (int y = 20; y < 80; y++) {
        for (int x = 20; x < 80; x++) {
          imageA.setPixelRgba(x, y, 200, 100, 80, 255);
        }
      }

      final imageB = img.Image(width: 120, height: 120);
      img.fill(imageB, color: img.ColorRgb8(80, 60, 50)); // Person B (different structure)
      for (int y = 40; y < 100; y++) {
        for (int x = 40; x < 100; x++) {
          imageB.setPixelRgba(x, y, 50, 150, 200, 255);
        }
      }

      final embeddingA = faceService.extractFaceEmbeddingFromBytes(img.encodeJpg(imageA))!;
      final embeddingB = faceService.extractFaceEmbeddingFromBytes(img.encodeJpg(imageB))!;

      final result = faceService.verifyFaceVector(embeddingB, embeddingA);
      expect(result.isSuccess, isFalse);
      expect(result.status, equals(FaceVerificationStatus.notRecognized));
      expect(result.message, equals('Face not recognized. Please try again.'));
      expect(result.similarityScore, lessThan(FaceRecognitionService.securityThreshold));
    });

    test('No face on pitch black/washed out frame returns null embedding', () {
      final darkImage = img.Image(width: 120, height: 120);
      img.fill(darkImage, color: img.ColorRgb8(0, 0, 0)); // Pitch black
      final darkBytes = img.encodeJpg(darkImage);

      final embedding = faceService.extractFaceEmbeddingFromBytes(darkBytes);
      expect(embedding, isNull);
    });
  });
}

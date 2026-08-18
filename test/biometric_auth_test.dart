import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:local_auth/local_auth.dart';
import 'package:ams_mobile_app/services/biometric_service.dart';
import 'package:ams_mobile_app/providers/biometric_provider.dart';
import 'package:ams_mobile_app/services/face_recognition_service.dart';

void main() {
  group('BiometricCapabilities Tests', () {
    test('Default BiometricCapabilities has all disabled/false flags', () {
      final caps = BiometricCapabilities.none;
      expect(caps.isSupported, isFalse);
      expect(caps.canCheckBiometrics, isFalse);
      expect(caps.hasFingerprint, isFalse);
      expect(caps.hasFace, isFalse);
      expect(caps.isBiometricEnabled, isFalse);
      expect(caps.isFingerprintEnabled, isFalse);
      expect(caps.isFaceLockEnabled, isFalse);
      expect(caps.isAvailable, isFalse);
    });

    test('isAvailable is true ONLY when supported, can check, AND enrolled', () {
      const unsupported = BiometricCapabilities(
        isSupported: false,
        canCheckBiometrics: true,
        hasEnrolledBiometrics: true,
        availableTypes: [BiometricType.fingerprint],
        isBiometricEnabled: true,
      );
      expect(unsupported.isAvailable, isFalse);

      const notEnrolled = BiometricCapabilities(
        isSupported: true,
        canCheckBiometrics: true,
        hasEnrolledBiometrics: false,
        availableTypes: [],
        isBiometricEnabled: true,
      );
      expect(notEnrolled.isAvailable, isFalse);

      const ready = BiometricCapabilities(
        isSupported: true,
        canCheckBiometrics: true,
        hasEnrolledBiometrics: true,
        availableTypes: [BiometricType.fingerprint],
        isBiometricEnabled: true,
      );
      expect(ready.isAvailable, isTrue);
    });

    test('BiometricCapabilities correctly reflects Face Lock capability', () {
      const faceOnly = BiometricCapabilities(
        isSupported: true,
        canCheckBiometrics: true,
        hasFace: true,
        availableTypes: [BiometricType.face],
        isFaceLockEnabled: true,
      );
      expect(faceOnly.hasFace, isTrue);
      expect(faceOnly.isFaceLockEnabled, isTrue);
    });
  });

  group('BiometricAuthResult Tests', () {
    test('BiometricAuthResult.success creates authenticated result without error', () {
      final result = BiometricAuthResult.success();
      expect(result.authenticated, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('BiometricAuthResult.failure creates unauthenticated result with error message', () {
      final result = BiometricAuthResult.failure('Wrong fingerprint');
      expect(result.authenticated, isFalse);
      expect(result.errorMessage, equals('Wrong fingerprint'));
    });
  });

  group('BiometricState Tests', () {
    test('BiometricState copyWith works properly', () {
      const state = BiometricState(
        capabilities: BiometricCapabilities.none,
        isAuthenticating: false,
        errorMessage: null,
      );

      final updated = state.copyWith(
        isAuthenticating: true,
        errorMessage: 'Authentication timeout',
      );

      expect(updated.isAuthenticating, isTrue);
      expect(updated.errorMessage, equals('Authentication timeout'));
    });
  });

  group('FaceRecognitionService Image Embedding Tests', () {
    final faceService = FaceRecognitionService();

    test('Identical vectors produce cosine similarity of 1.0', () {
      final vector = List.generate(640, (i) => (i + 1) / 640.0);
      final score = faceService.calculateCosineSimilarity(vector, vector);
      expect(score, closeTo(1.0, 0.0001));
    });

    test('Orthogonal / different vectors produce low similarity', () {
      final vectorA = List.generate(640, (i) => i < 320 ? 1.0 : -1.0);
      final vectorB = List.generate(640, (i) => i < 320 ? -1.0 : 1.0);
      final score = faceService.calculateCosineSimilarity(vectorA, vectorB);
      expect(score, lessThan(FaceRecognitionService.securityThreshold));
    });

    test('extractFaceEmbeddingFromBytes generates 640-dimensional embedding from image bytes', () {
      final testImage = img.Image(width: 120, height: 120);
      img.fill(testImage, color: img.ColorRgb8(200, 150, 120));
      for (int y = 30; y < 90; y++) {
        for (int x = 30; x < 90; x++) {
          testImage.setPixelRgba(x, y, x * 2, y * 2, 100, 255);
        }
      }
      final bytes = img.encodeJpg(testImage);
      final embedding = faceService.extractFaceEmbeddingFromBytes(bytes);

      expect(embedding, isNotNull);
      expect(embedding!.length, equals(640));
    });

    test('Comparing same image embedding succeeds with score > threshold', () {
      final testImage = img.Image(width: 120, height: 120);
      img.fill(testImage, color: img.ColorRgb8(200, 150, 120));
      for (int y = 20; y < 100; y++) {
        for (int x = 20; x < 100; x++) {
          testImage.setPixelRgba(x, y, (x * y) % 255, (x + y) % 255, 120, 255);
        }
      }
      final bytes = img.encodeJpg(testImage);
      final embedding1 = faceService.extractFaceEmbeddingFromBytes(bytes)!;

      final result = faceService.verifyFaceVector(embedding1, embedding1);
      expect(result.isSuccess, isTrue);
      expect(result.status, equals(FaceVerificationStatus.matched));
      expect(result.similarityScore, greaterThanOrEqualTo(FaceRecognitionService.securityThreshold));
    });

    test('Comparing different person image embedding is rejected with status notRecognized', () {
      final imageA = img.Image(width: 120, height: 120);
      img.fill(imageA, color: img.ColorRgb8(220, 180, 140)); // Person A
      for (int y = 0; y < 120; y++) {
        for (int x = 0; x < 120; x++) {
          if (x % 4 == 0) imageA.setPixelRgba(x, y, 100, 50, 40, 255);
        }
      }

      final imageB = img.Image(width: 120, height: 120);
      img.fill(imageB, color: img.ColorRgb8(80, 60, 50)); // Person B (different structure)
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
      expect(result.message, equals('Face does not match with your registered face.'));
      expect(result.similarityScore, lessThan(FaceRecognitionService.securityThreshold));
    });

    test('No face on pitch black/washed out frame returns null embedding', () {
      final darkImage = img.Image(width: 120, height: 120);
      img.fill(darkImage, color: img.ColorRgb8(0, 0, 0));
      final embedding = faceService.extractFaceEmbeddingFromBytes(img.encodeJpg(darkImage));
      expect(embedding, isNull);
    });
  });
}

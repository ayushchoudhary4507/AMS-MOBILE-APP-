import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Describes which biometric methods are available on the current device.
class BiometricCapabilities {
  final bool isSupported;
  final bool canCheckBiometrics;
  final bool hasEnrolledBiometrics;
  final bool hasFingerprint;
  final bool hasFace;
  final bool isBiometricEnabled;
  final bool isFingerprintEnabled;
  final bool isFaceLockEnabled;
  final String? savedUserName;
  final List<BiometricType> availableTypes;

  const BiometricCapabilities({
    this.isSupported = false,
    this.canCheckBiometrics = false,
    this.hasEnrolledBiometrics = false,
    this.hasFingerprint = false,
    this.hasFace = false,
    this.isBiometricEnabled = false,
    this.isFingerprintEnabled = false,
    this.isFaceLockEnabled = false,
    this.savedUserName,
    this.availableTypes = const [],
  });

  bool get hasFaceId => hasFace;

  // FIXED: isAvailable now correctly reflects whether biometrics are enrolled,
  // not just whether the device hardware supports it.
  bool get isAvailable => isSupported && canCheckBiometrics && hasEnrolledBiometrics;

  static const none = BiometricCapabilities(
    isSupported: false,
    canCheckBiometrics: false,
    hasEnrolledBiometrics: false,
    hasFingerprint: false,
    hasFace: false,
    isBiometricEnabled: false,
    isFingerprintEnabled: false,
    isFaceLockEnabled: false,
    availableTypes: [],
  );

  @override
  String toString() =>
      'BiometricCapabilities(supported: $isSupported, '
      'canCheck: $canCheckBiometrics, enrolled: $hasEnrolledBiometrics, '
      'fingerprint: $hasFingerprint, faceId: $hasFace, '
      'fingerprintEnabled: $isFingerprintEnabled, faceLockEnabled: $isFaceLockEnabled)';
}

/// Result of a biometric authentication attempt.
class BiometricAuthResult {
  /// Whether the user successfully authenticated.
  final bool authenticated;

  /// Human-readable reason why authentication was not successful (null on success).
  final String? errorMessage;

  const BiometricAuthResult._({required this.authenticated, this.errorMessage});

  factory BiometricAuthResult.success() =>
      const BiometricAuthResult._(authenticated: true);

  factory BiometricAuthResult.failure(String message) =>
      BiometricAuthResult._(authenticated: false, errorMessage: message);
}

/// Service wrapping [LocalAuthentication] for biometric capability detection
/// and secure token authentication.
class BiometricAuthService {
  static final BiometricAuthService _instance = BiometricAuthService._internal();
  factory BiometricAuthService() => _instance;
  BiometricAuthService._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static const String _keyBiometricEnabled = 'bio_enabled';
  static const String _keyFingerprintEnabled = 'bio_fingerprint_enabled';
  static const String _keyFaceLockEnabled = 'bio_facelock_enabled';
  static const String _keyToken = 'bio_token';
  static const String _keyUser = 'bio_user';
  static const String _keyRole = 'bio_role';

  /// Queries device biometric hardware and enrolled capabilities.
  Future<BiometricCapabilities> getCapabilities() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();

      // DEBUG LOG — safe, no sensitive data
      dev.log(
        '[BiometricAuthService] isDeviceSupported=$isDeviceSupported '
        'canCheckBiometrics=$canCheck',
        name: 'BiometricAuthService',
      );

      // Only fetch enrolled biometrics if the device supports it
      List<BiometricType> available = [];
      if (canCheck || isDeviceSupported) {
        available = await _auth.getAvailableBiometrics();
      }

      // DEBUG LOG — safe, lists biometric types only (not sensitive)
      dev.log(
        '[BiometricAuthService] Available biometric types: '
        '${available.map((t) => t.toString()).join(', ')}',
        name: 'BiometricAuthService',
      );

      final hasFingerprint = available.contains(BiometricType.fingerprint) ||
          (available.contains(BiometricType.strong) && !available.contains(BiometricType.face));

      final hasFace = available.contains(BiometricType.face) ||
          available.contains(BiometricType.weak) ||
          (available.contains(BiometricType.strong) && !available.contains(BiometricType.fingerprint));

      final isEnabledStr = await _secureStorage.read(key: _keyBiometricEnabled);
      final isFingerprintStr = await _secureStorage.read(key: _keyFingerprintEnabled);
      final isFaceLockStr = await _secureStorage.read(key: _keyFaceLockEnabled);

      final isEnabled = isEnabledStr == 'true';
      final isFingerprintEnabled = isFingerprintStr == 'true' || (isEnabled && isFingerprintStr == null);
      final isFaceLockEnabled = isFaceLockStr == 'true' || (isEnabled && isFaceLockStr == null);

      String? savedName;
      if (isEnabled || isFingerprintEnabled || isFaceLockEnabled) {
        final userStr = await _secureStorage.read(key: _keyUser);
        if (userStr != null) {
          try {
            final decoded = jsonDecode(userStr);
            if (decoded is Map) {
              savedName = decoded['name']?.toString();
            }
          } catch (_) {}
        }
      }

      final caps = BiometricCapabilities(
        // isSupported is true only when BOTH hardware is present AND biometrics are enrolled.
        // An un-enrolled device must NOT be treated as supported for login.
        isSupported: isDeviceSupported,
        canCheckBiometrics: canCheck,
        hasEnrolledBiometrics: available.isNotEmpty,
        hasFingerprint: hasFingerprint,
        hasFace: hasFace,
        isBiometricEnabled: isEnabled || isFingerprintEnabled || isFaceLockEnabled,
        isFingerprintEnabled: isFingerprintEnabled,
        isFaceLockEnabled: isFaceLockEnabled,
        savedUserName: savedName,
        availableTypes: available,
      );

      // DEBUG LOG — safe, no sensitive data
      dev.log(
        '[BiometricAuthService] Resolved capabilities → $caps',
        name: 'BiometricAuthService',
      );

      return caps;
    } catch (e, st) {
      dev.log(
        '[BiometricAuthService] getCapabilities() threw: $e',
        name: 'BiometricAuthService',
        error: e,
        stackTrace: st,
      );
      return BiometricCapabilities.none;
    }
  }

  /// Checks if device has any enrolled biometrics (fingerprint or face).
  /// Returns an empty list when the device does NOT have enrolled biometrics.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Prompts the user for biometric authentication.
  ///
  /// SECURITY CONTRACT:
  /// - Returns [BiometricAuthResult.success] ONLY when [LocalAuthentication.authenticate]
  ///   returns `true` AND the device has enrolled biometrics.
  /// - Returns [BiometricAuthResult.failure] in ALL other cases including:
  ///   - Device has no enrolled biometrics
  ///   - Biometric hardware is unsupported
  ///   - User cancels the prompt
  ///   - Authentication fails (wrong finger/face)
  ///   - Any exception from local_auth
  ///
  /// NEVER returns success on error/exception/cancellation.
  Future<BiometricAuthResult> authenticateWithResult({
    String localizedReason = 'Scan your biometrics to log in.',
    bool biometricOnly = false,
  }) async {
    try {
      // Step 1: Verify device supports biometrics
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      dev.log(
        '[BiometricAuthService] Biometric supported: $isDeviceSupported',
        name: 'BiometricAuthService',
      );
      if (!isDeviceSupported) {
        return BiometricAuthResult.failure(
          'This device does not support biometric authentication.',
        );
      }

      // Step 2: Verify the OS can check biometrics
      final bool canCheck = await _auth.canCheckBiometrics;
      dev.log(
        '[BiometricAuthService] Can check biometrics: $canCheck',
        name: 'BiometricAuthService',
      );
      if (!canCheck) {
        return BiometricAuthResult.failure(
          'Biometric authentication is not available on this device.',
        );
      }

      // Step 3: Verify at least one biometric is actually enrolled
      final List<BiometricType> available = await _auth.getAvailableBiometrics();
      dev.log(
        '[BiometricAuthService] Available biometrics: '
        '[${available.map((t) => t.toString()).join(', ')}]',
        name: 'BiometricAuthService',
      );
      if (available.isEmpty) {
        // No fingerprint or face is enrolled — DO NOT authenticate, DO NOT navigate
        return BiometricAuthResult.failure(
          'No fingerprint or face biometric is enrolled on this device.\n'
          'Please add a fingerprint or face lock in your device settings.',
        );
      }

      // Step 4: Show the native biometric prompt and capture the ACTUAL result
      final bool result = await _auth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
          useErrorDialogs: true,
        ),
      );

      // DEBUG LOG — safe, only logs true/false
      dev.log(
        '[BiometricAuthService] Authentication result: $result',
        name: 'BiometricAuthService',
      );

      // Step 5: ONLY return success when authenticate() literally returned true.
      // If result is false (user cancelled, wrong biometric, etc.), return failure.
      if (result == true) {
        return BiometricAuthResult.success();
      } else {
        return BiometricAuthResult.failure(
          'Biometric verification failed. Please try again.',
        );
      }
    } on PlatformException catch (e, st) {
      dev.log(
        '[BiometricAuthService] PlatformException during authenticate: code=${e.code}',
        name: 'BiometricAuthService',
        error: e,
        stackTrace: st,
      );

      // Map known error codes to user-friendly messages.
      // CRITICAL: NEVER return success here — exceptions are failures.
      String message;
      switch (e.code) {
        case 'NotEnrolled':
          message = 'No fingerprint or face biometric is enrolled on this device.\n'
              'Please add a fingerprint or face lock in your device settings.';
          break;
        case 'NotAvailable':
          message = 'Biometric authentication is not available on this device.';
          break;
        case 'LockedOut':
          message = 'Too many failed attempts. Biometric authentication is temporarily locked.';
          break;
        case 'PermanentlyLockedOut':
          message = 'Biometric authentication is permanently locked due to too many failed attempts.';
          break;
        case 'no_fragment_activity':
          message = 'Authentication context is unavailable. Please restart the app.';
          break;
        default:
          message = 'Biometric authentication error: ${e.message ?? e.code}';
      }
      return BiometricAuthResult.failure(message);
    } catch (e, st) {
      dev.log(
        '[BiometricAuthService] Unexpected error during authenticate: $e',
        name: 'BiometricAuthService',
        error: e,
        stackTrace: st,
      );
      // CRITICAL: Any unexpected error MUST result in failure, NEVER success.
      return BiometricAuthResult.failure(
        'An unexpected error occurred during biometric authentication.',
      );
    }
  }

  /// Checks whether fingerprint is enrolled specifically.
  Future<bool> isFingerprintEnrolled() async {
    try {
      final available = await _auth.getAvailableBiometrics();
      dev.log(
        '[BiometricAuthService] isFingerprintEnrolled -> available: '
        '${available.map((t) => t.name).join(', ')}',
        name: 'BiometricAuthService',
      );
      if (available.contains(BiometricType.fingerprint)) return true;
      if (available.contains(BiometricType.strong) && !available.contains(BiometricType.face)) return true;
      if (available.contains(BiometricType.weak) && !available.contains(BiometricType.face) && !available.contains(BiometricType.strong)) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Checks whether face authentication is enrolled specifically.
  Future<bool> isFaceEnrolled() async {
    try {
      final isFaceEnabled = (await _secureStorage.read(key: _keyFaceLockEnabled)) == 'true';
      return isFaceEnabled;
    } catch (_) {
      return false;
    }
  }

  /// Securely saves session data for biometric login.
  static Future<void> enableBiometricLogin({
    required String token,
    required Map<String, dynamic> user,
    required String role,
    bool enableFingerprint = true,
    bool enableFaceLock = true,
  }) async {
    try {
      await _secureStorage.write(key: _keyBiometricEnabled, value: 'true');
      await _secureStorage.write(key: _keyFingerprintEnabled, value: enableFingerprint ? 'true' : 'false');
      await _secureStorage.write(key: _keyFaceLockEnabled, value: enableFaceLock ? 'true' : 'false');
      await _secureStorage.write(key: _keyToken, value: token);
      await _secureStorage.write(key: _keyUser, value: jsonEncode(user));
      await _secureStorage.write(key: _keyRole, value: role);
    } catch (_) {}
  }

  /// Disables biometric login & clears stored session.
  static Future<void> disableBiometricLogin() async {
    try {
      await _secureStorage.delete(key: _keyBiometricEnabled);
      await _secureStorage.delete(key: _keyFingerprintEnabled);
      await _secureStorage.delete(key: _keyFaceLockEnabled);
      await _secureStorage.delete(key: _keyToken);
      await _secureStorage.delete(key: _keyUser);
      await _secureStorage.delete(key: _keyRole);
    } catch (_) {}
  }

  /// Toggle fingerprint option specifically
  static Future<void> setFingerprintEnabled(bool enabled, {
    String? token,
    Map<String, dynamic>? user,
    String? role,
  }) async {
    try {
      await _secureStorage.write(key: _keyFingerprintEnabled, value: enabled ? 'true' : 'false');
      final faceEnabled = (await _secureStorage.read(key: _keyFaceLockEnabled)) == 'true';
      await _secureStorage.write(key: _keyBiometricEnabled, value: (enabled || faceEnabled) ? 'true' : 'false');
      if (enabled && token != null && user != null) {
        await _secureStorage.write(key: _keyToken, value: token);
        await _secureStorage.write(key: _keyUser, value: jsonEncode(user));
        if (role != null) await _secureStorage.write(key: _keyRole, value: role);
      }
    } catch (_) {}
  }

  /// Toggle face lock option specifically
  static Future<void> setFaceLockEnabled(bool enabled, {
    String? token,
    Map<String, dynamic>? user,
    String? role,
  }) async {
    try {
      await _secureStorage.write(key: _keyFaceLockEnabled, value: enabled ? 'true' : 'false');
      final fpEnabled = (await _secureStorage.read(key: _keyFingerprintEnabled)) == 'true';
      await _secureStorage.write(key: _keyBiometricEnabled, value: (enabled || fpEnabled) ? 'true' : 'false');
      if (enabled && token != null && user != null) {
        await _secureStorage.write(key: _keyToken, value: token);
        await _secureStorage.write(key: _keyUser, value: jsonEncode(user));
        if (role != null) await _secureStorage.write(key: _keyRole, value: role);
      }
    } catch (_) {}
  }

  /// Retrieves securely stored session for biometric login.
  static Future<Map<String, dynamic>?> getSecureSession() async {
    try {
      final isEnabled = await _secureStorage.read(key: _keyBiometricEnabled);
      final fpEnabled = await _secureStorage.read(key: _keyFingerprintEnabled);
      final faceEnabled = await _secureStorage.read(key: _keyFaceLockEnabled);

      final isAnyEnabled = isEnabled == 'true' || fpEnabled == 'true' || faceEnabled == 'true';
      if (!isAnyEnabled) return null;

      final token = await _secureStorage.read(key: _keyToken);
      final userStr = await _secureStorage.read(key: _keyUser);
      final role = await _secureStorage.read(key: _keyRole);

      if (token == null || token.isEmpty || userStr == null || userStr.isEmpty) {
        return null;
      }

      final user = jsonDecode(userStr);
      if (user is Map) {
        return {
          'token': token,
          'user': Map<String, dynamic>.from(user),
          'role': role ?? 'employee',
        };
      }
    } catch (_) {}
    return null;
  }

  /// Checks if biometric hardware is supported AND biometrics are enrolled.
  /// Returns false if either condition is not met.
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;
      // Must also check that at least one biometric is actually enrolled
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Checks if biometric lock flag is enabled in secure storage.
  Future<bool> isBiometricLockEnabled() async {
    try {
      final session = await getSecureSession();
      if (session == null) return false;

      final isEnabled = await _secureStorage.read(key: _keyBiometricEnabled);
      final fpEnabled = await _secureStorage.read(key: _keyFingerprintEnabled);
      final faceEnabled = await _secureStorage.read(key: _keyFaceLockEnabled);
      return isEnabled == 'true' || fpEnabled == 'true' || faceEnabled == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Enables app-level biometric lock.
  Future<void> enableBiometricLock({
    required String token,
    required Map<String, dynamic> user,
    required String role,
  }) async {
    await enableBiometricLogin(token: token, user: user, role: role);
  }

  /// Disables app-level biometric lock.
  Future<void> disableBiometricLock() async {
    await disableBiometricLogin();
  }
}

/// Legacy alias for compatibility with existing codebase
typedef BiometricService = BiometricAuthService;

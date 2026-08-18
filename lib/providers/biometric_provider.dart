import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/biometric_service.dart';

class BiometricState {
  final BiometricCapabilities capabilities;
  final bool isAuthenticating;
  final String? errorMessage;

  const BiometricState({
    this.capabilities = const BiometricCapabilities(),
    this.isAuthenticating = false,
    this.errorMessage,
  });

  BiometricState copyWith({
    BiometricCapabilities? capabilities,
    bool? isAuthenticating,
    String? errorMessage,
  }) {
    return BiometricState(
      capabilities: capabilities ?? this.capabilities,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      errorMessage: errorMessage,
    );
  }
}

class BiometricNotifier extends StateNotifier<BiometricState> {
  final BiometricAuthService _authService = BiometricAuthService();

  BiometricNotifier() : super(const BiometricState()) {
    checkCapabilities();
  }

  Future<void> checkCapabilities() async {
    final caps = await _authService.getCapabilities();
    state = state.copyWith(capabilities: caps, errorMessage: null);
  }

  /// Authenticates the user using the device biometric and returns the stored session.
  ///
  /// SECURITY CONTRACT:
  /// - First verifies that the specific biometric type ([fingerprintOnly] / face) is enrolled.
  /// - Only calls native authentication AFTER enrollment is confirmed.
  /// - Only returns the session when [BiometricAuthResult.authenticated] == true.
  /// - Returns null in ALL failure/cancel/error cases — never logs the user in.
  ///
  /// [fingerprintOnly] — when true, specifically checks fingerprint enrollment.
  ///                     when false, specifically checks face enrollment.
  ///                     when null, checks any biometric enrollment.
  Future<Map<String, dynamic>?> authenticateAndGetSession(
    String reason, {
    bool isAdmin = false,
    bool? fingerprintOnly,
  }) async {
    if (state.isAuthenticating) return null; // Prevent duplicate requests

    state = state.copyWith(isAuthenticating: true, errorMessage: null);

    try {
      // --- Step 1: Check that a session exists (user previously enabled biometric login) ---
      final session = await BiometricAuthService.getSecureSession();
      if (session == null) {
        state = state.copyWith(
          isAuthenticating: false,
          errorMessage:
              'Biometric lock is disabled. Please login with your password and enable '
              'Fingerprint / Face Lock in Settings.',
        );
        return null;
      }

      // --- Step 2: Check whether the requested biometric type is actually enrolled ---
      if (fingerprintOnly == true) {
        // User tapped "Login with Fingerprint" — check fingerprint specifically
        final enrolled = await _authService.isFingerprintEnrolled();
        dev.log(
          '[BiometricNotifier] Fingerprint enrolled: $enrolled',
          name: 'BiometricNotifier',
        );
        if (!enrolled) {
          state = state.copyWith(
            isAuthenticating: false,
            errorMessage:
                'Fingerprint authentication is not available on this device. '
                'Please configure fingerprint in your device settings or use another supported biometric method.',
          );
          return null;
        }
      } else if (fingerprintOnly == false) {
        // User tapped "Login with Face Unlock" — check face specifically
        final enrolled = await _authService.isFaceEnrolled();
        dev.log(
          '[BiometricNotifier] Face enrolled: $enrolled',
          name: 'BiometricNotifier',
        );
        if (!enrolled) {
          state = state.copyWith(
            isAuthenticating: false,
            errorMessage:
                'Face Unlock is not available on this device. '
                'Please configure Face Unlock in your device settings or use another supported biometric method.',
          );
          return null;
        }
      } else {
        // Generic check — any enrolled biometric will do
        final available = await _authService.getAvailableBiometrics();
        dev.log(
          '[BiometricNotifier] Available biometrics: '
          '[${available.map((t) => t.toString()).join(', ')}]',
          name: 'BiometricNotifier',
        );
        if (available.isEmpty) {
          state = state.copyWith(
            isAuthenticating: false,
            errorMessage:
                'No fingerprint or face biometric is enrolled on this device. '
                'Please add a fingerprint or face lock in your device settings.',
          );
          return null;
        }
      }

      // --- Step 3: Show native biometric prompt and check the ACTUAL result ---
      // SECURITY FIX: biometricOnly=true is ALWAYS enforced so the user CANNOT
      // bypass face/fingerprint auth using a PIN, pattern, or device password.
      // Setting biometricOnly=false (the old behaviour for face unlock) allowed
      // Android's device-credential fallback, meaning *any* face (or a known PIN)
      // could unlock the app — a critical security hole.
      final BiometricAuthResult authResult = await _authService.authenticateWithResult(
        localizedReason: reason,
        biometricOnly: true, // ALWAYS true — no PIN/pattern/password fallback allowed
      );

      dev.log(
        '[BiometricNotifier] Authentication result: ${authResult.authenticated}',
        name: 'BiometricNotifier',
      );

      if (authResult.authenticated == true) {
        // Biometric was genuinely successful — return the session
        state = state.copyWith(isAuthenticating: false, errorMessage: null);
        return session;
      } else {
        // Authentication failed, was cancelled, or threw an error
        final defaultErrMsg = fingerprintOnly == false
            ? 'Face not recognized. Please try again.'
            : 'Biometric verification failed. Please try again.';
        state = state.copyWith(
          isAuthenticating: false,
          errorMessage: authResult.errorMessage ?? defaultErrMsg,
        );
        return null;
      }
    } catch (e) {
      // Catch-all: any unexpected error MUST keep the user on the Login screen
      dev.log(
        '[BiometricNotifier] Unexpected error in authenticateAndGetSession: $e',
        name: 'BiometricNotifier',
      );
      state = state.copyWith(
        isAuthenticating: false,
        errorMessage: fingerprintOnly == false
            ? 'Face not recognized. Please try again.'
            : 'Biometric authentication failed. Please try again.',
      );
      return null;
    }
  }

  Future<void> enableBiometric({
    required String token,
    required Map<String, dynamic> user,
    required String role,
  }) async {
    await BiometricAuthService.enableBiometricLogin(
      token: token,
      user: user,
      role: role,
    );
    await checkCapabilities();
  }

  Future<void> setFingerprintEnabled(
    bool enable, {
    String? token,
    Map<String, dynamic>? user,
    String? role,
  }) async {
    await BiometricAuthService.setFingerprintEnabled(
      enable,
      token: token,
      user: user,
      role: role,
    );
    await checkCapabilities();
  }

  Future<void> setFaceLockEnabled(
    bool enable, {
    String? token,
    Map<String, dynamic>? user,
    String? role,
  }) async {
    await BiometricAuthService.setFaceLockEnabled(
      enable,
      token: token,
      user: user,
      role: role,
    );
    await checkCapabilities();
  }

  Future<void> disableBiometric() async {
    await BiometricAuthService.disableBiometricLogin();
    await checkCapabilities();
  }
}

final biometricProvider =
    StateNotifierProvider<BiometricNotifier, BiometricState>((ref) {
  return BiometricNotifier();
});

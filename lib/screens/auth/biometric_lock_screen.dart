import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/biometric_provider.dart';
import '../../widgets/auth/face_camera_auth_dialog.dart';
import '../../widgets/common/app_logo.dart';

class BiometricLockScreen extends ConsumerStatefulWidget {

  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  bool _isAuthenticating = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(biometricProvider.notifier).checkCapabilities();
      _triggerBiometricAuth('Unlock AMS to continue');
    });
  }

  Future<void> _triggerFaceCameraAuth() async {
    if (_isAuthenticating) return;

    final success = await FaceCameraAuthDialog.show(
      context,
      title: 'Face Unlock',
      subtitle: 'Align your face in the front camera to unlock',
      onFallbackToFingerprint: () =>
          _triggerBiometricAuth('Scan Fingerprint to Unlock App'),
      onFallbackToPassword: _fallbackToPassword,
    );

    if (success && mounted) {
      final auth = ref.read(authProvider);
      if (auth.isAdmin) {
        context.go('/admin/dashboard');
      } else {
        context.go('/employee/dashboard');
      }
    }
  }

  Future<void> _triggerBiometricAuth(String reason) async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _statusMessage = null;
    });

    try {
      final session = await ref
          .read(biometricProvider.notifier)
          .authenticateAndGetSession(reason, fingerprintOnly: true);

      if (session != null && mounted) {
        final success = await ref
            .read(authProvider.notifier)
            .restoreBiometricSession(session);

        if (success && mounted) {
          final auth = ref.read(authProvider);
          if (auth.isAdmin) {
            context.go('/admin/dashboard');
          } else {
            context.go('/employee/dashboard');
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _statusMessage = ref.read(biometricProvider).errorMessage ??
              'Authentication failed. Please scan your biometrics or use password.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _statusMessage = 'Biometric error occurred. Try again or use password.';
        });
      }
    }
  }

  Future<void> _fallbackToPassword() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bioState = ref.watch(biometricProvider);
    final caps = bioState.capabilities;
    final auth = ref.watch(authProvider);
    final userName = caps.savedUserName ??
        auth.user?['name']?.toString() ??
        'User';

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: context.mainBgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              children: [
                // Top Header Row
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, color: AppColors.primary, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'App Locked',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Center Biometric Graphic & Welcome Card
                const AppLogo(
                  size: 84,
                  fontSize: 28,
                  borderRadius: 24,
                )
                    .animate()
                    .scale(duration: const Duration(milliseconds: 500), curve: Curves.easeOutBack),

                const SizedBox(height: 24),

                Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: context.txtPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Unlock the app using Fingerprint or Face Camera Scanner',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.txtSecondary,
                  ),
                ),

                if (_statusMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accentRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.accentRed, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _statusMessage!,
                            style: const TextStyle(
                              color: AppColors.accentRed,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(),
                ],

                const Spacer(),

                // Action Buttons: Fingerprint, Face Camera Scan, and Password Fallback
                Column(
                  children: [
                    // Fingerprint Scan Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const ValueKey('app_lock_fingerprint_btn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.fingerprint_rounded, size: 24),
                        label: Text(
                          _isAuthenticating ? 'Scanning...' : 'Unlock with Fingerprint',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        onPressed: _isAuthenticating
                            ? null
                            : () => _triggerBiometricAuth('Scan Fingerprint to Unlock App'),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Face Unlock (Camera) Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey('app_lock_face_btn'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF06B6D4),
                          side: const BorderSide(color: Color(0xFF06B6D4), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.face_retouching_natural_rounded, size: 24),
                        label: const Text(
                          'Open Camera Face Unlock',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        onPressed: _isAuthenticating
                            ? null
                            : _triggerFaceCameraAuth,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Fallback to Password Login
                    TextButton.icon(
                      key: const ValueKey('app_lock_use_password_btn'),
                      onPressed: _fallbackToPassword,
                      icon: Icon(Icons.lock_outline_rounded, size: 18, color: context.txtSecondary),
                      label: Text(
                        'Use Password Login',
                        style: TextStyle(
                          color: context.txtSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

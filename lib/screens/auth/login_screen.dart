import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/biometric_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/biometric_service.dart';
import '../../widgets/auth/face_camera_auth_dialog.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/attendance_pro_icon.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(biometricProvider.notifier).checkCapabilities();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Navigate to correct dashboard based on role from server response.
  void _navigateByRole() {
    final auth = ref.read(authProvider);
    if (auth.isAdmin) {
      context.go('/admin/dashboard');
    } else {
      context.go('/employee/dashboard');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );

    if (success && mounted) {
      final auth = ref.read(authProvider);

      // Only refresh stored biometric session credentials if the user has ALREADY enabled it explicitly
      final caps = ref.read(biometricProvider).capabilities;
      if (caps.isBiometricEnabled && auth.token != null && auth.user != null) {
        await ref.read(biometricProvider.notifier).enableBiometric(
              token: auth.token!,
              user: auth.user!,
              role: auth.role ?? 'employee',
              enableFingerprint: caps.isFingerprintEnabled,
              enableFaceLock: caps.isFaceLockEnabled,
            );
      }

      if (mounted) _navigateByRole();
    } else if (mounted) {
      final error = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Login failed'),
          backgroundColor: AppColors.accentRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  /// Handles biometric login tap.
  ///
  /// [reason]          — the localized prompt shown in the native biometric dialog.
  /// [fingerprintOnly] — true  = fingerprint button tapped (native fingerprint prompt).
  ///                     false = face button tapped      (opens Camera Face Unlock directly).
  Future<void> _handleBiometricLogin(String reason, {required bool fingerprintOnly}) async {
    if (!fingerprintOnly) {
      final caps = ref.read(biometricProvider).capabilities;
      if (!caps.isFaceLockEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Face Lock is not enabled. Please log in with your password and enable Face Lock in Settings.',
            ),
            backgroundColor: AppColors.accentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      // Direct Camera Face Unlock - No OS Fingerprint Dialog
      final success = await FaceCameraAuthDialog.show(
        context,
        title: 'Face Unlock',
        subtitle: 'Position your face inside the circle to log in',
        isEnrollment: false,
        onFallbackToFingerprint: () => _handleBiometricLogin(
          'Authenticate with Fingerprint',
          fingerprintOnly: true,
        ),
      );

      if (success && mounted) {
        _navigateByRole();
      }
      return;
    }

    final session = await ref
        .read(biometricProvider.notifier)
        .authenticateAndGetSession(
          reason,
          fingerprintOnly: fingerprintOnly,
        );

    if (session != null && mounted) {
      // Biometric authentication was genuinely successful — restore the session.
      final success = await ref
          .read(authProvider.notifier)
          .restoreBiometricSession(session);

      if (success && mounted) {
        _navigateByRole();
      } else if (mounted) {
        // Session restored but auth state failed (e.g. expired JWT)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Your session has expired. Please login with your password.',
            ),
            backgroundColor: AppColors.accentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else if (mounted) {
      // Authentication failed/cancelled/no biometric — stay on Login screen.
      final err = ref.read(biometricProvider).errorMessage;
      if (err != null && err.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: AppColors.accentRed,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final bioState = ref.watch(biometricProvider);
    final caps = bioState.capabilities;
    final isLoading = authState.status == AuthStatus.loading || bioState.isAuthenticating;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // ── Web Ambient Radial Background ──
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -1.0),
                  radius: 1.35,
                  colors: isDark
                      ? const [
                          Color(0xFF1E1B4B),
                          Color(0xFF0F172A),
                          Color(0xFF090D16),
                        ]
                      : const [
                          Color(0xFFE0E7FF),
                          Color(0xFFF8FAFC),
                          Color(0xFFF1F5F9),
                        ],
                  stops: const [0.0, 0.40, 1.0],
                ),
              ),
            ),
          ),

          // Top-right purple glow blob
          Positioned(
            top: -60,
            right: -40,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7C3AED).withValues(alpha: isDark ? 0.38 : 0.14),
                      const Color(0xFF7C3AED).withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.70],
                  ),
                ),
              ),
            ),
          ),

          // Bottom-left blue glow blob
          Positioned(
            bottom: -40,
            left: -30,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.35 : 0.12),
                      const Color(0xFF4F46E5).withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.70],
                  ),
                ),
              ),
            ),
          ),

          // ── Scrollable Content Area ──
          SafeArea(
            child: Column(
              children: [
                // Top Navigation Bar (Back + Theme Toggle)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      InkWell(
                        onTap: () {
                          if (Navigator.of(context).canPop()) {
                            context.pop();
                          } else {
                            context.go('/');
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: context.txtPrimary,
                          ),
                        ),
                      ),

                      // Theme Switcher
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: Icon(
                          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF475569),
                          size: 20,
                        ),
                        onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
                      ),
                    ],
                  ),
                ),

                // Main Form Card Scrollable
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Form(
                      key: _formKey,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A).withValues(alpha: 0.82)
                              : Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.08),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                              blurRadius: 28,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          borderRadius: BorderRadius.circular(24),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Brand Header
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const AttendanceProIcon(size: 36),
                                    const SizedBox(width: 10),
                                    Text(
                                      'AttendancePro',
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        color: context.txtPrimary,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 18),

                                // Welcome Back Title & Subtitle
                                Center(
                                  child: Column(
                                    children: [
                                      ShaderMask(
                                        shaderCallback: (bounds) => const LinearGradient(
                                          colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                                        ).createShader(bounds),
                                        child: const Text(
                                          'Welcome Back',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Sign in to access your portal',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: context.txtSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Email Address Field
                                Text(
                                  'Email Address',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: context.txtPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                CustomTextField(
                                  key: const ValueKey('email_text_field'),
                                  controller: _emailController,
                                  label: 'Email Address',
                                  hint: 'Enter your email',
                                  prefixIcon: Icons.mail_outline_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Email is required';
                                    if (!v.contains('@')) return 'Enter valid email';
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 16),

                                // Password Field
                                Text(
                                  'Password',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: context.txtPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                CustomTextField(
                                  key: const ValueKey('password_text_field'),
                                  controller: _passwordController,
                                  label: 'Password',
                                  hint: 'Enter your password',
                                  prefixIcon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: context.txtMuted,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Password is required';
                                    if (v.length < 4) return 'Min 4 characters';
                                    return null;
                                  },
                                ),

                                // Forgot Password Link
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    key: const ValueKey('forgot_password_btn'),
                                    onPressed: () => _showForgotPasswordModal(context),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: Color(0xFF6366F1),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // Main Login to Dashboard CTA Button
                                InkWell(
                                  key: const ValueKey('login_submit_btn'),
                                  onTap: isLoading ? null : _login,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Ink(
                                    width: double.infinity,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF4F46E5).withValues(alpha: 0.38),
                                          blurRadius: 16,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: isLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Text(
                                              'Login to Dashboard',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),

                                // Biometric & Alternative Login Section (Fingerprint & Face Unlock)
                                _buildSecondaryBiometricSection(caps),

                                const SizedBox(height: 20),

                                // Sign Up Nav Prompt
                                Center(
                                  child: GestureDetector(
                                    key: const ValueKey('register_nav_btn'),
                                    onTap: () => context.go('/register'),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color: context.txtSecondary,
                                          ),
                                          text: "Don't have an account? ",
                                          children: const [
                                            TextSpan(
                                              text: 'Sign Up',
                                              style: TextStyle(
                                                color: Color(0xFF6366F1),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Biometric & OTP Login Buttons Section Below Login Button ---
  Widget _buildSecondaryBiometricSection(BiometricCapabilities caps) {
    final isDark = context.isDark;

    return Column(
      key: const ValueKey('sec_bio_section_col'),
      children: [
        const SizedBox(height: 20),
        Row(
          key: const ValueKey('sec_bio_divider_row'),
          children: [
            Expanded(child: Divider(color: context.dividerCol)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OR SIGN IN WITH',
                style: TextStyle(
                  color: context.txtMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            Expanded(child: Divider(color: context.dividerCol)),
          ],
        ),
        const SizedBox(height: 14),

        // 1. Prominent Email OTP Button
        InkWell(
          key: const ValueKey('email_otp_login_btn'),
          onTap: () => _showEmailOtpLoginModal(context),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                  : const Color(0xFF10B981).withValues(alpha: 0.08),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.5),
                width: 1.3,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF10B981), size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Login with Email OTP',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, color: Color(0xFF10B981), size: 16),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // 2. Fingerprint & Face Unlock Row
        Row(
          key: const ValueKey('sec_bio_btn_row'),
          children: [
            // Fingerprint Lock Button
            Expanded(
              child: InkWell(
                key: const ValueKey('fingerprint_outline_inkwell'),
                onTap: () => _handleBiometricLogin(
                  'Authenticate with Fingerprint',
                  fingerprintOnly: true,
                ),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF6366F1).withValues(alpha: 0.1)
                        : const Color(0xFF6366F1).withValues(alpha: 0.05),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.45),
                      width: 1.3,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fingerprint, color: Color(0xFF6366F1), size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Fingerprint',
                        style: TextStyle(
                          color: Color(0xFF6366F1),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Face Unlock Camera Button
            Expanded(
              child: InkWell(
                key: const ValueKey('face_outline_inkwell'),
                onTap: () => _handleBiometricLogin(
                  'Authenticate with Face Unlock',
                  fingerprintOnly: false,
                ),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF06B6D4).withValues(alpha: 0.1)
                        : const Color(0xFF06B6D4).withValues(alpha: 0.05),
                    border: Border.all(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.45),
                      width: 1.3,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.face_rounded, color: Color(0xFF06B6D4), size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Face Unlock',
                        style: TextStyle(
                          color: Color(0xFF06B6D4),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showEmailOtpLoginModal(BuildContext context) {
    final emailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    final otpController = TextEditingController();

    int currentStep = 1; // 1 = Enter Email & Send OTP, 2 = Enter 6-digit OTP & Login
    bool isSubmitting = false;
    String? errorText;
    int resendCountdown = 0;
    Timer? countdownTimer;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void startTimer() {
              countdownTimer?.cancel();
              resendCountdown = 60;
              countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
                if (resendCountdown > 0) {
                  setModalState(() => resendCountdown--);
                } else {
                  timer.cancel();
                }
              });
            }

            Future<void> sendOtp() async {
              final email = emailController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                setModalState(() => errorText = 'Please enter a valid email address');
                return;
              }

              setModalState(() {
                isSubmitting = true;
                errorText = null;
              });

              final res = await ref.read(authProvider.notifier).sendLoginOtp(email);

              if (res != null) {
                setModalState(() {
                  isSubmitting = false;
                  currentStep = 2;
                  errorText = null;
                });
                startTimer();
              } else {
                final err = ref.read(authProvider).error;
                setModalState(() {
                  isSubmitting = false;
                  errorText = err ?? 'Failed to send OTP code to $email';
                });
              }
            }

            Future<void> verifyOtpAndLogin() async {
              final email = emailController.text.trim();
              final otp = otpController.text.trim();

              if (otp.length < 4) {
                setModalState(() => errorText = 'Please enter the complete OTP code');
                return;
              }

              setModalState(() {
                isSubmitting = true;
                errorText = null;
              });

              final success = await ref
                  .read(authProvider.notifier)
                  .loginWithOtp(email, otp);

              if (success && mounted) {
                countdownTimer?.cancel();
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text('Logged in successfully via OTP!'),
                      ],
                    ),
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
                _navigateByRole();
              } else {
                final err = ref.read(authProvider).error;
                setModalState(() {
                  isSubmitting = false;
                  errorText = err ?? 'Invalid OTP code. Please check and try again.';
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: context.borderCol, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: context.isDark ? 0.4 : 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: context.txtMuted.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              currentStep == 1
                                  ? Icons.mark_email_read_rounded
                                  : Icons.verified_user_rounded,
                              color: const Color(0xFF10B981),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentStep == 1
                                      ? 'Login with Email OTP'
                                      : 'Enter Verification Code',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: context.txtPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentStep == 1
                                      ? 'Step 1 of 2: Get OTP code on your Email'
                                      : 'Step 2 of 2: Enter OTP to Login',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.txtMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            color: context.txtMuted,
                            onPressed: () {
                              countdownTimer?.cancel();
                              Navigator.of(ctx).pop();
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Error banner
                      if (errorText != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.accentRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.accentRed.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.accentRed,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  errorText!,
                                  style: const TextStyle(
                                    color: AppColors.accentRed,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Step 1: Request OTP
                      if (currentStep == 1) ...[
                        Text(
                          'Email Address',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.txtPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        CustomTextField(
                          controller: emailController,
                          label: 'Email Address',
                          hint: 'Enter your registered email',
                          prefixIcon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),
                        CustomButton(
                          label: 'Send Login Code',
                          isLoading: isSubmitting,
                          onPressed: isSubmitting ? null : sendOtp,
                        ),
                      ],

                      // Step 2: Enter OTP & Login
                      if (currentStep == 2) ...[
                        // Email target info banner
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.email_outlined, color: Color(0xFF10B981), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'OTP sent to ${emailController.text.trim()}',
                                  style: TextStyle(
                                    color: context.txtPrimary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  countdownTimer?.cancel();
                                  setModalState(() {
                                    currentStep = 1;
                                    errorText = null;
                                  });
                                },
                                child: const Text(
                                  'Edit',
                                  style: TextStyle(
                                    color: Color(0xFF6366F1),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'Verification Code (OTP)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.txtPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        CustomTextField(
                          controller: otpController,
                          label: 'OTP Code',
                          hint: 'Enter 6-digit OTP code',
                          prefixIcon: Icons.pin_outlined,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),

                        // Resend OTP Countdown
                        Align(
                          alignment: Alignment.centerRight,
                          child: resendCountdown > 0
                              ? Text(
                                  'Resend OTP in ${resendCountdown}s',
                                  style: TextStyle(
                                    color: context.txtMuted,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              : TextButton(
                                  onPressed: isSubmitting ? null : sendOtp,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text(
                                    'Resend Code',
                                    style: TextStyle(
                                      color: Color(0xFF6366F1),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                        ),

                        const SizedBox(height: 14),

                        CustomButton(
                          label: 'Verify & Login',
                          isLoading: isSubmitting,
                          onPressed: isSubmitting ? null : verifyOtpAndLogin,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showForgotPasswordModal(BuildContext context) {
    bool isPhoneMode = false; // Default to Email OTP
    final identifierController = TextEditingController(
      text: _emailController.text.trim(),
    );
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    int currentStep = 1; // 1 = Request OTP, 2 = Enter OTP & Set New Password
    bool isSubmitting = false;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: context.borderCol, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: context.isDark ? 0.4 : 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: context.txtMuted.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1)
                                  .withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              currentStep == 1
                                  ? (isPhoneMode
                                      ? Icons.phone_android_rounded
                                      : Icons.mark_email_read_rounded)
                                  : Icons.lock_reset_rounded,
                              color: const Color(0xFF6366F1),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentStep == 1
                                      ? 'Forgot Password?'
                                      : 'Reset Password',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: context.txtPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentStep == 1
                                      ? 'Step 1 of 2: Get OTP on Phone / Email'
                                      : 'Step 2 of 2: Enter OTP & New Password',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.txtMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded,
                                color: context.txtMuted),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (errorText != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: Color(0xFFEF4444), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorText!,
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (currentStep == 1) ...[
                        Text(
                          'Choose where you would like to receive your real-time OTP verification code:',
                          style: TextStyle(
                            color: context.txtSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Channel Toggle: Phone vs Email
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: context.inputFillBg,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: context.borderCol, width: 1),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      isPhoneMode = true;
                                      errorText = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isPhoneMode
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.phone_iphone_rounded,
                                          size: 18,
                                          color: isPhoneMode
                                              ? Colors.white
                                              : context.txtMuted,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Phone SMS',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isPhoneMode
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isPhoneMode
                                                ? Colors.white
                                                : context.txtSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      isPhoneMode = false;
                                      errorText = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !isPhoneMode
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.mail_outline_rounded,
                                          size: 18,
                                          color: !isPhoneMode
                                              ? Colors.white
                                              : context.txtMuted,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Email',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: !isPhoneMode
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: !isPhoneMode
                                                ? Colors.white
                                                : context.txtSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Input field for Phone or Email
                        CustomTextField(
                          controller: identifierController,
                          label: isPhoneMode
                              ? 'Mobile Phone Number'
                              : 'Email Address',
                          hint: isPhoneMode
                              ? 'e.g. +91 9876543210 or 9876543210'
                              : 'e.g. user@domain.com',
                          prefixIcon: isPhoneMode
                              ? Icons.phone_outlined
                              : Icons.email_outlined,
                          keyboardType: isPhoneMode
                              ? TextInputType.phone
                              : TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 22),

                        CustomButton(
                          label: isSubmitting
                              ? 'Sending OTP (please wait)...'
                              : (isPhoneMode
                                  ? 'Send OTP to Phone'
                                  : 'Send OTP to Email'),
                          isLoading: isSubmitting,
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final idVal =
                                      identifierController.text.trim();
                                  if (isPhoneMode) {
                                    final cleanDigits =
                                        idVal.replaceAll(RegExp(r'\D'), '');
                                    if (cleanDigits.length < 8) {
                                      setModalState(() {
                                        errorText =
                                            'Please enter a valid phone number (at least 8 digits)';
                                      });
                                      return;
                                    }
                                  } else {
                                    final emailRegex =
                                        RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
                                    if (idVal.isEmpty ||
                                        !emailRegex.hasMatch(idVal)) {
                                      setModalState(() {
                                        errorText =
                                            'Please enter a valid email address (e.g. name@example.com)';
                                      });
                                      return;
                                    }
                                  }

                                  setModalState(() {
                                    isSubmitting = true;
                                    errorText = null;
                                  });

                                  final res = await ref
                                      .read(authProvider.notifier)
                                      .sendForgotPasswordOtp(idVal);

                                  if (res != null && ctx.mounted) {
                                    otpController.clear();
                                    setModalState(() {
                                      isSubmitting = false;
                                      currentStep = 2;
                                      errorText = null;
                                    });
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'OTP sent to $idVal! Please check your ${isPhoneMode ? "SMS messages" : "Gmail / email inbox"}.',
                                        ),
                                        backgroundColor:
                                            const Color(0xFF10B981),
                                        duration: const Duration(seconds: 5),
                                      ),
                                    );
                                  } else {
                                    setModalState(() {
                                      isSubmitting = false;
                                      errorText =
                                          ref.read(authProvider).error ??
                                              'Failed to send OTP code. Please check your details.';
                                    });
                                  }
                                },
                        ),
                      ] else ...[
                        Text(
                          'Enter the 6-digit OTP code received on ${identifierController.text.trim()} and set your new password.',
                          style: TextStyle(
                            color: context.txtSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Color(0xFF6366F1), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isPhoneMode
                                      ? 'OTP sent via SMS. Check your messages, or tap "Resend OTP".'
                                      : 'OTP is sent to your Gmail / Email. Check your Inbox & Spam folder, or tap "Resend OTP".',
                                  style: const TextStyle(
                                    color: Color(0xFF6366F1),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // OTP Code Field (User enters manually)
                        CustomTextField(
                          controller: otpController,
                          label: 'OTP / Verification Code',
                          hint: 'Enter 6-digit OTP from Gmail/SMS',
                          prefixIcon: Icons.pin_outlined,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          enableSuggestions: false,
                          autocorrect: false,
                          autofillHints: const [],
                          counter: const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 14),

                        // New Password Field
                        CustomTextField(
                          controller: newPasswordController,
                          label: 'New Password',
                          hint: 'Enter new password (min 4 chars)',
                          prefixIcon: Icons.lock_outline,
                          obscureText: obscureNew,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNew
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: context.txtMuted,
                              size: 20,
                            ),
                            onPressed: () => setModalState(
                                () => obscureNew = !obscureNew),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Confirm New Password Field
                        CustomTextField(
                          controller: confirmPasswordController,
                          label: 'Confirm New Password',
                          hint: 'Re-enter new password',
                          prefixIcon: Icons.lock_outline,
                          obscureText: obscureConfirm,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: context.txtMuted,
                              size: 20,
                            ),
                            onPressed: () => setModalState(
                                () => obscureConfirm = !obscureConfirm),
                          ),
                        ),
                        const SizedBox(height: 22),

                        CustomButton(
                          label: isSubmitting
                              ? 'Verifying OTP & Resetting...'
                              : 'Reset Password',
                          isLoading: isSubmitting,
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final otp = otpController.text.trim();
                                  final newPass = newPasswordController.text;
                                  final confirmPass =
                                      confirmPasswordController.text;

                                  if (otp.isEmpty) {
                                    setModalState(() => errorText =
                                        'Please enter the OTP verification code');
                                    return;
                                  }
                                  if (newPass.length < 4) {
                                    setModalState(() => errorText =
                                        'Password must be at least 4 characters');
                                    return;
                                  }
                                  if (newPass != confirmPass) {
                                    setModalState(() => errorText =
                                        'Passwords do not match');
                                    return;
                                  }

                                  setModalState(() {
                                    isSubmitting = true;
                                    errorText = null;
                                  });

                                  final idVal =
                                      identifierController.text.trim();
                                  final ok = await ref
                                      .read(authProvider.notifier)
                                      .resetPasswordWithOtp(
                                        identifier: idVal,
                                        otp: otp,
                                        newPassword: newPass,
                                      );

                                  if (ok && ctx.mounted) {
                                    Navigator.pop(ctx);
                                    if (idVal.contains('@')) {
                                      _emailController.text = idVal;
                                    }
                                    _passwordController.text = newPass;
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Password reset successfully! You can now log in.'),
                                          backgroundColor: Color(0xFF10B981),
                                          duration: Duration(seconds: 4),
                                        ),
                                      );
                                    }
                                  } else {
                                    setModalState(() {
                                      isSubmitting = false;
                                      errorText =
                                          ref.read(authProvider).error ??
                                              'Failed to reset password. Invalid OTP or expired code.';
                                    });
                                  }
                                },
                        ),
                        const SizedBox(height: 12),

                        // Back to Step 1 or Resend OTP
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () => setModalState(() {
                                        currentStep = 1;
                                        errorText = null;
                                      }),
                              icon: const Icon(Icons.arrow_back_rounded,
                                  size: 16),
                              label: const Text(
                                'Change phone/email',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      final idVal =
                                          identifierController.text.trim();
                                      setModalState(() {
                                        isSubmitting = true;
                                        errorText = null;
                                      });
                                      final res = await ref
                                          .read(authProvider.notifier)
                                          .sendForgotPasswordOtp(idVal);
                                      setModalState(
                                          () => isSubmitting = false);
                                      if (res != null && ctx.mounted) {
                                        otpController.clear();
                                        ScaffoldMessenger.of(ctx)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'New OTP sent to $idVal! Please check your ${isPhoneMode ? "SMS messages" : "Gmail / email inbox"}.',
                                            ),
                                            backgroundColor:
                                                const Color(0xFF10B981),
                                          ),
                                        );
                                      } else {
                                        setModalState(() {
                                          errorText = ref
                                                  .read(authProvider)
                                                  .error ??
                                              'Failed to resend OTP.';
                                        });
                                      }
                                    },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text(
                                'Resend OTP',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}


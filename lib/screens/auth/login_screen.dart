import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/biometric_provider.dart';
import '../../services/biometric_service.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/app_logo.dart';

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

      // Silently save session for biometric login without showing any popup dialog
      if (auth.token != null && auth.user != null) {
        await ref.read(biometricProvider.notifier).enableBiometric(
              token: auth.token!,
              user: auth.user!,
              role: auth.role ?? 'employee',
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
  /// [fingerprintOnly] — true  = fingerprint button tapped (checks fingerprint enrollment).
  ///                     false = face button tapped      (checks face enrollment).
  Future<void> _handleBiometricLogin(String reason, {required bool fingerprintOnly}) async {
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

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: context.mainBgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: context.txtSecondary),
                    onPressed: () => context.go('/welcome'),
                  ),
                  const SizedBox(height: 8),

                  // Logo
                  const Center(
                    child: AppLogo(
                      size: 88,
                      fontSize: 26,
                      borderRadius: 24,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Welcome Back',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: context.txtPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign in to continue',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: context.txtSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Email Field
                  CustomTextField(
                    key: const ValueKey('email_text_field'),
                    controller: _emailController,
                    label: 'Email Address',
                    hint: 'Enter your email',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Email is required';
                      if (!v.contains('@')) return 'Enter valid email';
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  // Password Field
                  CustomTextField(
                    key: const ValueKey('password_text_field'),
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Enter your password',
                    prefixIcon: Icons.lock_outline,
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

                  // Forgot Password Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const ValueKey('forgot_password_btn'),
                      onPressed: () => _showForgotPasswordModal(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Login Button
                  CustomButton(
                    key: const ValueKey('login_submit_btn'),
                    label: isLoading ? 'Signing in...' : 'Login',
                    isLoading: isLoading,
                    onPressed: _login,
                  ),

                  // Biometric Login Buttons (Fingerprint & Face Unlock)
                  _buildSecondaryBiometricSection(caps),

                  const SizedBox(height: 20),

                  // Register Link
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: GestureDetector(
                        key: const ValueKey('register_nav_btn'),
                        onTap: () => context.go('/register'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 14,
                                color: context.txtSecondary,
                              ),
                              text: "Don't have an account? ",
                              children: const [
                                TextSpan(
                                  text: 'Register',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
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
    );
  }

  // --- Biometric Buttons Section Below Login Button ---
  Widget _buildSecondaryBiometricSection(BiometricCapabilities caps) {
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
                'OR LOGIN WITH BIOMETRICS',
                style: TextStyle(
                  color: context.txtMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Expanded(child: Divider(color: context.dividerCol)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          key: const ValueKey('sec_bio_btn_row'),
          children: [
            Expanded(
              child: Material(
                key: const ValueKey('fingerprint_outline_mat'),
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: const ValueKey('fingerprint_outline_inkwell'),
                  onTap: () => _handleBiometricLogin(
                    'Authenticate with Fingerprint',
                    fingerprintOnly: true,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fingerprint, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Fingerprint',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Material(
                key: const ValueKey('face_outline_mat'),
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: const ValueKey('face_outline_inkwell'),
                  onTap: () => _handleBiometricLogin(
                    'Authenticate with Face Unlock',
                    fingerprintOnly: false,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF06B6D4), width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.face_rounded, color: Color(0xFF06B6D4), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Face Unlock',
                          style: TextStyle(
                            color: Color(0xFF06B6D4),
                            fontSize: 13,
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
      ],
    );
  }

  void _showForgotPasswordModal(BuildContext context) {
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    int currentStep = 1; // 1 = Enter Email & Send OTP, 2 = Enter OTP & Reset Password
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: context.borderCol, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: context.isDark ? 0.4 : 0.1),
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
                              color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              currentStep == 1
                                  ? Icons.mark_email_read_rounded
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
                                  currentStep == 1 ? 'Forgot Password?' : 'Reset Password',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: context.txtPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentStep == 1
                                      ? 'Step 1 of 2: Request OTP Code'
                                      : 'Step 2 of 2: Set New Password',
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
                            icon: Icon(Icons.close_rounded, color: context.txtMuted),
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
                            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
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
                          'Enter your registered email address below. We will send you an OTP verification code.',
                          style: TextStyle(
                            color: context.txtSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),

                        CustomTextField(
                          controller: resetEmailController,
                          label: 'Email Address',
                          hint: 'e.g. user@domain.com',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 22),

                        CustomButton(
                          label: isSubmitting ? 'Sending OTP Code...' : 'Send Reset Code',
                          isLoading: isSubmitting,
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final email = resetEmailController.text.trim();
                                  if (email.isEmpty || !email.contains('@')) {
                                    setModalState(() {
                                      errorText = 'Please enter a valid email address';
                                    });
                                    return;
                                  }

                                  setModalState(() {
                                    isSubmitting = true;
                                    errorText = null;
                                  });

                                  final ok = await ref
                                      .read(authProvider.notifier)
                                      .sendForgotPasswordOtp(email);

                                  if (ok && ctx.mounted) {
                                    setModalState(() {
                                      isSubmitting = false;
                                      currentStep = 2;
                                      errorText = null;
                                    });
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text('OTP code sent! Please check your email inbox.'),
                                        backgroundColor: Color(0xFF10B981),
                                      ),
                                    );
                                  } else {
                                    setModalState(() {
                                      isSubmitting = false;
                                      errorText = ref.read(authProvider).error ??
                                          'Failed to send OTP code. Please try again.';
                                    });
                                  }
                                },
                        ),
                      ] else ...[
                        Text(
                          'Enter the OTP code received on ${resetEmailController.text.trim()} and your new password.',
                          style: TextStyle(
                            color: context.txtSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // OTP Code Field
                        CustomTextField(
                          controller: otpController,
                          label: 'OTP / Verification Code',
                          hint: 'Enter 6-digit OTP code',
                          prefixIcon: Icons.pin_outlined,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 14),

                        // New Password Field
                        CustomTextField(
                          controller: newPasswordController,
                          label: 'New Password',
                          hint: 'Enter new password',
                          prefixIcon: Icons.lock_outline,
                          obscureText: obscureNew,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: context.txtMuted,
                              size: 20,
                            ),
                            onPressed: () => setModalState(() => obscureNew = !obscureNew),
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
                              obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: context.txtMuted,
                              size: 20,
                            ),
                            onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                          ),
                        ),
                        const SizedBox(height: 22),

                        CustomButton(
                          label: isSubmitting ? 'Resetting Password...' : 'Reset Password',
                          isLoading: isSubmitting,
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final otp = otpController.text.trim();
                                  final newPass = newPasswordController.text;
                                  final confirmPass = confirmPasswordController.text;

                                  if (otp.isEmpty) {
                                    setModalState(() => errorText = 'Please enter OTP code');
                                    return;
                                  }
                                  if (newPass.length < 4) {
                                    setModalState(() => errorText = 'Password must be at least 4 characters');
                                    return;
                                  }
                                  if (newPass != confirmPass) {
                                    setModalState(() => errorText = 'Passwords do not match');
                                    return;
                                  }

                                  setModalState(() {
                                    isSubmitting = true;
                                    errorText = null;
                                  });

                                  final ok = await ref
                                      .read(authProvider.notifier)
                                      .resetPasswordWithOtp(
                                        email: resetEmailController.text.trim(),
                                        otp: otp,
                                        newPassword: newPass,
                                      );

                                  if (ok && ctx.mounted) {
                                    Navigator.pop(ctx);
                                    _emailController.text = resetEmailController.text.trim();
                                    _passwordController.text = newPass;
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Password reset successfully! You can now log in.'),
                                          backgroundColor: Color(0xFF10B981),
                                          duration: Duration(seconds: 4),
                                        ),
                                      );
                                    }
                                  } else {
                                    setModalState(() {
                                      isSubmitting = false;
                                      errorText = ref.read(authProvider).error ??
                                          'Failed to reset password. Invalid OTP or expired code.';
                                    });
                                  }
                                },
                        ),
                        const SizedBox(height: 12),

                        // Back to Step 1 or Resend OTP
                        Center(
                          child: TextButton(
                            onPressed: isSubmitting
                                ? null
                                : () => setModalState(() {
                                      currentStep = 1;
                                      errorText = null;
                                    }),
                            child: const Text(
                              'Change email or resend code',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
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


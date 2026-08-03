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
                  const SizedBox(height: 16),

                  // Logo
                  const Center(
                    child: AppLogo(
                      size: 88,
                      fontSize: 26,
                      borderRadius: 24,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: context.txtPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sign in to continue',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: context.txtSecondary,
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

                  const SizedBox(height: 22),

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
}

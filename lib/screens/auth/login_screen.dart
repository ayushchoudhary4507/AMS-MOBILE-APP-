import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isAdmin = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
          isAdmin: _isAdmin,
        );

    if (success && mounted) {
      final auth = ref.read(authProvider);
      if (auth.isAdmin || _isAdmin) {
        context.go('/admin/dashboard');
      } else {
        context.go('/employee/dashboard');
      }
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  // Logo
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 25,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fingerprint,
                        color: Colors.white,
                        size: 42,
                      ),
                    ).animate().scale(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.elasticOut,
                        ),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    _isAdmin ? 'Admin Login' : 'Welcome Back',
                    style: Theme.of(context).textTheme.displayMedium,
                  ).animate().slideX(
                        begin: -0.2,
                        end: 0,
                        duration: const Duration(milliseconds: 400),
                      ),

                  const SizedBox(height: 8),

                  Text(
                    'Sign in to your account',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ).animate().fadeIn(delay: const Duration(milliseconds: 200)),

                  const SizedBox(height: 36),

                  // Toggle Admin/Employee
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgCardLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isAdmin = false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: !_isAdmin
                                    ? AppColors.primaryGradient
                                    : null,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  'Employee',
                                  style: TextStyle(
                                    color: !_isAdmin
                                        ? Colors.white
                                        : AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isAdmin = true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: _isAdmin
                                    ? AppColors.primaryGradient
                                    : null,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  'Admin',
                                  style: TextStyle(
                                    color: _isAdmin
                                        ? Colors.white
                                        : AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: const Duration(milliseconds: 300)),

                  const SizedBox(height: 28),

                  // Email Field
                  CustomTextField(
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
                  ).animate().slideY(
                        begin: 0.2,
                        end: 0,
                        delay: const Duration(milliseconds: 350),
                        duration: const Duration(milliseconds: 400),
                      ),

                  const SizedBox(height: 16),

                  // Password Field
                  CustomTextField(
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
                        color: AppColors.textMuted,
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
                  ).animate().slideY(
                        begin: 0.2,
                        end: 0,
                        delay: const Duration(milliseconds: 400),
                        duration: const Duration(milliseconds: 400),
                      ),

                  const SizedBox(height: 32),

                  // Login Button
                  CustomButton(
                    label: isLoading
                        ? 'Signing in...'
                        : (_isAdmin ? 'Admin Login' : 'Login'),
                    isLoading: isLoading,
                    onPressed: _login,
                  ).animate().slideY(
                        begin: 0.2,
                        end: 0,
                        delay: const Duration(milliseconds: 450),
                        duration: const Duration(milliseconds: 400),
                      ),

                  const SizedBox(height: 24),

                  // Register Link (Employee only)
                  if (!_isAdmin)
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/register'),
                        child: RichText(
                          text: const TextSpan(
                            text: "Don't have an account? ",
                            style: TextStyle(color: AppColors.textSecondary),
                            children: [
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
                    ).animate().fadeIn(delay: const Duration(milliseconds: 500)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await AuthService.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        _phoneController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registered successfully! Please login.'),
            backgroundColor: AppColors.statusPresent,
          ),
        );
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString()}'),
            backgroundColor: AppColors.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(gradient: context.mainBgGradient),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 40,
                    ),
                    child: IntrinsicHeight(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconButton(
                              icon: Icon(Icons.arrow_back_ios,
                                  color: context.txtSecondary),
                              onPressed: () => context.go('/login'),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: context.txtPrimary,
                              ),
                            ).animate().slideX(
                                  begin: -0.2,
                                  end: 0,
                                  duration: const Duration(milliseconds: 400),
                                ),
                            const SizedBox(height: 8),
                            Text(
                              'Join the Attendance Management System',
                              style: TextStyle(
                                  fontSize: 14, color: context.txtSecondary),
                            ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
                            const SizedBox(height: 28),
                            CustomTextField(
                              controller: _nameController,
                              label: 'Full Name',
                              hint: 'Enter your full name',
                              prefixIcon: Icons.person_outline,
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Name is required' : null,
                            ).animate().slideY(
                                  begin: 0.2,
                                  end: 0,
                                  delay: const Duration(milliseconds: 300),
                                  duration: const Duration(milliseconds: 400),
                                ),
                            const SizedBox(height: 16),
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
                            CustomTextField(
                              controller: _phoneController,
                              label: 'Phone Number',
                              hint: 'Enter phone number',
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Phone is required' : null,
                            ).animate().slideY(
                                  begin: 0.2,
                                  end: 0,
                                  delay: const Duration(milliseconds: 400),
                                  duration: const Duration(milliseconds: 400),
                                ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hint: 'Create a password',
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
                                if (v.length < 6) return 'Min 6 characters';
                                return null;
                              },
                            ).animate().slideY(
                                  begin: 0.2,
                                  end: 0,
                                  delay: const Duration(milliseconds: 450),
                                  duration: const Duration(milliseconds: 400),
                                ),
                            const SizedBox(height: 28),
                            CustomButton(
                              label: _isLoading ? 'Creating Account...' : 'Register',
                              isLoading: _isLoading,
                              onPressed: _register,
                            ).animate().slideY(
                                  begin: 0.2,
                                  end: 0,
                                  delay: const Duration(milliseconds: 500),
                                  duration: const Duration(milliseconds: 400),
                                ),
                            const Spacer(),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 16, bottom: 8),
                                child: TextButton(
                                  onPressed: () => context.go('/login'),
                                  child: Text(
                                    'Already have an account? Login',
                                    style: TextStyle(color: context.txtSecondary),
                                  ),
                                ),
                              ),
                            ).animate().fadeIn(delay: const Duration(milliseconds: 550)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

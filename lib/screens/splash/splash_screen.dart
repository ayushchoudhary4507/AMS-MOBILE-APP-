import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    final auth = ref.read(authProvider);
    if (auth.isAuthenticated) {
      if (auth.isAdmin) {
        context.go('/admin/dashboard');
      } else {
        context.go('/employee/dashboard');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.fingerprint,
                  color: Colors.white,
                  size: 52,
                ),
              )
                  .animate()
                  .scale(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                  )
                  .fadeIn(duration: const Duration(milliseconds: 400)),

              const SizedBox(height: 28),

              // Title
              const Text(
                'AMS',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              )
                  .animate()
                  .slideY(
                    begin: 0.3,
                    end: 0,
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  )
                  .fadeIn(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 300),
                  ),

              const SizedBox(height: 8),

              const Text(
                'Attendance Management System',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  letterSpacing: 1,
                ),
              )
                  .animate()
                  .fadeIn(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 500),
                  ),

              const SizedBox(height: 60),

              // Loading indicator
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                ),
              ).animate().fadeIn(
                    delay: const Duration(milliseconds: 800),
                    duration: const Duration(milliseconds: 400),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

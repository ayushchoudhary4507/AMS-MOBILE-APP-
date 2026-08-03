import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../services/biometric_service.dart';
import '../../widgets/common/app_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    BiometricAuthService.disableBiometricLogin();
    _navigate();
  }

  Future<void> _navigate() async {
    final startTime = DateTime.now();

    // Wait until authNotifier finishes checking stored auth status
    while (ref.read(authProvider).status == AuthStatus.initial) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (DateTime.now().difference(startTime).inMilliseconds > 2000) break;
    }

    // Minimum splash duration for smooth logo animation
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    if (elapsed < 600) {
      await Future.delayed(Duration(milliseconds: 600 - elapsed));
    }

    if (!mounted) return;

    final auth = ref.read(authProvider);

    if (auth.isAuthenticated) {
      final lastRoute = await StorageService.getLastRoute();
      if (!mounted) return;

      if (lastRoute != null && lastRoute.isNotEmpty) {
        // Restore exact last open screen if compatible with role
        if (auth.isAdmin && (lastRoute.startsWith('/admin') || lastRoute == '/notifications')) {
          context.go(lastRoute);
          return;
        } else if (!auth.isAdmin && (lastRoute.startsWith('/employee') || lastRoute == '/notifications')) {
          context.go(lastRoute);
          return;
        }
      }

      if (auth.isAdmin) {
        context.go('/admin/dashboard');
      } else {
        context.go('/employee/dashboard');
      }
    } else {
      context.go('/welcome');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              const AppLogo(
                size: 96,
                fontSize: 32,
                borderRadius: 28,
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
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                ),
              ).animate().fadeIn(
                    delay: const Duration(milliseconds: 800),
                    duration: const Duration(milliseconds: 400),
                  ),
            ],
          ),
        ),
      ),
    ),
  );
 }
}

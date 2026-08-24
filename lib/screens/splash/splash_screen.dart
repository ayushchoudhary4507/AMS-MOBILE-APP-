import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/attendance_pro_icon.dart';

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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: SizedBox.expand(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0F172A),
                Color(0xFF0A0F1D),
                Color(0xFF020617),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing Ambient Logo Container
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Soft Glow Aura
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                            blurRadius: 50,
                            spreadRadius: 10,
                          ),
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                            blurRadius: 80,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                    ),

                    // Vector Brand Icon
                    const AttendanceProIcon(
                      size: 104,
                      borderRadius: 26,
                      hasShadow: true,
                    )
                        .animate()
                        .scale(
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.elasticOut,
                        )
                        .fadeIn(duration: const Duration(milliseconds: 400)),
                  ],
                ),

                const SizedBox(height: 32),

                // Brand Title
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Attendance',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        shadows: [
                          Shadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF818CF8), Color(0xFF38BDF8)],
                      ).createShader(bounds),
                      child: const Text(
                        'Pro',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                )
                    .animate()
                    .slideY(
                      begin: 0.3,
                      end: 0,
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                    )
                    .fadeIn(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 250),
                    ),

                const SizedBox(height: 8),

                // Subtitle Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Text(
                    'Smart Biometric & Face Recognition',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.3,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 400),
                    ),

                const SizedBox(height: 54),

                // Sleek Loader
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    color: const Color(0xFF6366F1),
                    strokeWidth: 2.5,
                    backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  ),
                ).animate().fadeIn(
                      delay: const Duration(milliseconds: 600),
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

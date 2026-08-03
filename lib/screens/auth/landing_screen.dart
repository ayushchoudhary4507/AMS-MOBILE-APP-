import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/custom_button.dart';

class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: context.mainBgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const SizedBox(height: 12),

                const Spacer(),

                // Center Brand Section
                const AppLogo(
                  size: 90,
                  fontSize: 30,
                  borderRadius: 26,
                ).animate().scale(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutBack,
                    ),

                const SizedBox(height: 24),

                Text(
                  'Attendance Management System',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: context.txtPrimary,
                    letterSpacing: -0.5,
                  ),
                ).animate().fadeIn(delay: const Duration(milliseconds: 200)),

                const SizedBox(height: 10),

                Text(
                  'Smart workforce tracking, seamless check-ins,\nand biometric security all in one app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: context.txtSecondary,
                  ),
                ).animate().fadeIn(delay: const Duration(milliseconds: 300)),

                const SizedBox(height: 36),

                // Feature Highlights Chips / Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildFeatureCard(
                        context: context,
                        icon: Icons.fingerprint_rounded,
                        color: AppColors.primary,
                        title: 'Biometrics',
                        subtitle: 'Fingerprint & Face',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFeatureCard(
                        context: context,
                        icon: Icons.access_time_filled_rounded,
                        color: const Color(0xFF06B6D4),
                        title: 'Real-Time',
                        subtitle: 'Instant Check-in',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFeatureCard(
                        context: context,
                        icon: Icons.shield_rounded,
                        color: const Color(0xFF10B981),
                        title: 'Secure',
                        subtitle: 'Encrypted Log',
                      ),
                    ),
                  ],
                ).animate().slideY(
                      begin: 0.2,
                      end: 0,
                      delay: const Duration(milliseconds: 400),
                      duration: const Duration(milliseconds: 400),
                    ),

                const Spacer(),

                // Action Buttons Section
                Column(
                  children: [
                    CustomButton(
                      key: const ValueKey('landing_get_started_btn'),
                      label: 'Get Started',
                      onPressed: () => context.go('/login'),
                    ),

                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        key: const ValueKey('landing_register_btn'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.txtPrimary,
                          side: BorderSide(color: context.borderCol, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => context.go('/register'),
                        child: Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.txtPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ).animate().slideY(
                      begin: 0.3,
                      end: 0,
                      delay: const Duration(milliseconds: 500),
                      duration: const Duration(milliseconds: 400),
                    ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderCol),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.txtPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: context.txtMuted,
            ),
          ),
        ],
      ),
    );
  }
}

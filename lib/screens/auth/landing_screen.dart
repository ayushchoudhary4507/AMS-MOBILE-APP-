import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/landing/landing_hero_slider.dart';
import '../../widgets/landing/landing_dashboard_preview.dart';
import '../../widgets/landing/landing_features_section.dart';
import '../../widgets/landing/landing_footer.dart';

class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showSearchModal(BuildContext context) {
    final isDark = context.isDark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131728) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: context.borderCol, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quick Search',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.txtPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: context.txtSecondary,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                style: TextStyle(color: context.txtPrimary),
                decoration: InputDecoration(
                  hintText: 'Search employees, attendance records...',
                  hintStyle: TextStyle(color: context.txtMuted, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6366F1)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E2238) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/login');
                  },
                  child: const Text(
                    'Search Records',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '💡 Try: Employee name, Department, Date',
                style: TextStyle(fontSize: 12, color: context.txtMuted),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showConfigModal(BuildContext context) {
    final isDark = context.isDark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131728) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: context.borderCol, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Advanced Configuration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.txtPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        color: context.txtSecondary,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Section 1: Attendance Settings
                  Text(
                    'ATTENDANCE SETTINGS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF6366F1),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildConfigItem(context, 'Work Hours', '09:00 - 18:00'),
                  _buildConfigItem(context, 'Grace Period', '15 minutes'),
                  _buildConfigItem(context, 'Real-time Notifications', 'Active'),

                  const SizedBox(height: 14),

                  // Section 2: Reports
                  Text(
                    'REPORTS & SYNC',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF6366F1),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildConfigItem(context, 'Daily Reports', 'Automated'),
                  _buildConfigItem(context, 'Cloud Sync Engine', 'Operational 🟢'),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        context.go('/login');
                      },
                      child: const Text(
                        'Open Full Settings',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildConfigItem(BuildContext context, String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1B2036) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderCol.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.txtPrimary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6366F1),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // ── Exact Ambient Background Layer from Web (radial-gradient(circle at 50% 0%, ...)) ──
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -1.0), // 50% 0%
                  radius: 1.35,
                  colors: isDark
                      ? const [
                          Color(0xFF1E1B4B), // #1e1b4b 0%
                          Color(0xFF0F172A), // #0f172a 40%
                          Color(0xFF090D16), // #090d16 100%
                        ]
                      : const [
                          Color(0xFFE0E7FF), // #e0e7ff 0%
                          Color(0xFFF8FAFC), // #f8fafc 40%
                          Color(0xFFF1F5F9), // #f1f5f9 100%
                        ],
                  stops: const [0.0, 0.40, 1.0],
                ),
              ),
            ),
          ),

          // ── Ambient Glow Blobs Matching Web LandingPage.css ──
          // 1. Purple Blob (top: -100px, right: -50px, #7c3aed)
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
                      const Color(0xFF7C3AED).withValues(alpha: isDark ? 0.40 : 0.14),
                      const Color(0xFF7C3AED).withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.70],
                  ),
                ),
              ),
            ),
          ),

          // 2. Cyan Blob (top: 30%, right: 10%, #06b6d4)
          Positioned(
            top: 240,
            right: -20,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF06B6D4).withValues(alpha: isDark ? 0.30 : 0.10),
                      const Color(0xFF06B6D4).withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.70],
                  ),
                ),
              ),
            ),
          ),

          // 3. Blue Blob (bottom: -50px, left: 5%, #4f46e5)
          Positioned(
            bottom: -30,
            left: -20,
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

          // ── Main Scrollable Content ──
          SafeArea(
            child: Column(
              children: [
                // ── Top Navigation Bar ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0A0F1E).withValues(alpha: 0.75)
                        : Colors.white.withValues(alpha: 0.82),
                  ),
                  child: Row(
                    children: [
                      // Logo Box & Title (Left Side)
                      Expanded(
                        child: InkWell(
                          onTap: () => _scrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOut,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Text('📋', style: TextStyle(fontSize: 14)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'AttendancePro',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: context.txtPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 4),

                      // Right Action Group: Theme Toggle + Login + Sign Up (Far Right)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Theme Toggle
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                            icon: Icon(
                              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF475569),
                              size: 18,
                            ),
                            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
                          ),

                          const SizedBox(width: 4),

                          // Login Button (Web Primary Pill)
                          InkWell(
                            onTap: () => context.go('/login'),
                            borderRadius: BorderRadius.circular(50),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                ),
                                borderRadius: BorderRadius.circular(50),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 5),

                          // Sign Up Button (Web Secondary Outline Pill)
                          InkWell(
                            onTap: () => context.go('/register'),
                            borderRadius: BorderRadius.circular(50),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : const Color(0xFF4F46E5).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : const Color(0xFF4F46E5).withValues(alpha: 0.5),
                                  width: 1.3,
                                ),
                              ),
                              child: Text(
                                'Sign Up',
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF4F46E5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Scrollable Body ──
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),

                        // 1. Top Dedicated Photo Slider Banner
                        const LandingHeroSlider(),

                        const SizedBox(height: 16),

                        // 2. Hero Header & Copy
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Gradient Main Title
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [
                                    Color(0xFF818CF8),
                                    Color(0xFFC084FC),
                                    Color(0xFF38BDF8),
                                  ],
                                ).createShader(bounds),
                                child: const Text(
                                  'ATTENDANCE WEB SYSTEM',
                                  style: TextStyle(
                                    fontSize: 25,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                    height: 1.15,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 6),

                              Text(
                                'Modern dashboard UI with Light & Dark Mode',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: context.txtPrimary,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                'Streamline your workforce management with our intelligent attendance tracking system. Real-time insights, automated reporting, and seamless integration.',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: context.txtSecondary,
                                ),
                              ),

                              const SizedBox(height: 18),

                              // 3 Feature Stat Badges (Smart / Real-time / Secure)
                              Row(
                                children: [
                                  _buildStatBadge(context, 'Smart', 'Attendance\nTracking', const Color(0xFF6366F1)),
                                  const SizedBox(width: 8),
                                  _buildStatBadge(context, 'Real-time', 'Dashboard\nAnalytics', const Color(0xFF06B6D4)),
                                  const SizedBox(width: 8),
                                  _buildStatBadge(context, 'Secure', 'Cloud Based\nSystem', const Color(0xFF10B981)),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Action CTA Buttons
                              Row(
                                children: [
                                  Expanded(
                                    flex: 6,
                                    child: InkWell(
                                      onTap: () => context.go('/login'),
                                      borderRadius: BorderRadius.circular(50),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                          ),
                                          borderRadius: BorderRadius.circular(50),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                                              blurRadius: 16,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Get Started',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              SizedBox(width: 6),
                                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 17),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 5,
                                    child: InkWell(
                                      onTap: () => context.go('/register'),
                                      borderRadius: BorderRadius.circular(50),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.06)
                                              : const Color(0xFF4F46E5).withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(50),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.white.withValues(alpha: 0.45)
                                                : const Color(0xFF4F46E5).withValues(alpha: 0.45),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Sign Up',
                                            style: TextStyle(
                                              color: isDark ? Colors.white : const Color(0xFF4F46E5),
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 3. Interactive Live Dashboard Preview (HeroVisualCarousel)
                        LandingDashboardPreview(
                          onNavigateLogin: () => context.go('/login'),
                          onOpenSearch: () => _showSearchModal(context),
                          onOpenConfig: () => _showConfigModal(context),
                        ),

                        // 4. Core Capabilities / Features Section
                        const LandingFeaturesSection(),

                        // 5. Modern Footer
                        LandingFooter(
                          onNavigateLogin: () => context.go('/login'),
                        ),
                      ],
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

  Widget _buildStatBadge(BuildContext context, String title, String subtitle, Color accentColor) {
    final isDark = context.isDark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF131728).withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: accentColor,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                height: 1.15,
                fontWeight: FontWeight.w600,
                color: context.txtSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

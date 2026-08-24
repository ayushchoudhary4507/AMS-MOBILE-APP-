import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class FeatureItem {
  final String icon;
  final String title;
  final String desc;
  final List<Color> gradientColors;

  const FeatureItem({
    required this.icon,
    required this.title,
    required this.desc,
    required this.gradientColors,
  });
}

class LandingFeaturesSection extends StatelessWidget {
  const LandingFeaturesSection({super.key});

  static const List<FeatureItem> _features = [
    FeatureItem(
      icon: '📊',
      title: 'Live Analytics Dashboard',
      desc: 'Monitor attendance trends with real-time data visualization and instant insights',
      gradientColors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
    ),
    FeatureItem(
      icon: '🔒',
      title: 'Enterprise Security',
      desc: 'Role-based access control with encrypted data storage and secure authentication',
      gradientColors: [Color(0xFF10B981), Color(0xFF059669)],
    ),
    FeatureItem(
      icon: '⏱️',
      title: 'Smart Time Tracking',
      desc: 'Automated work hour calculations with intelligent late arrival detection',
      gradientColors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    ),
    FeatureItem(
      icon: '📱',
      title: 'Access Anywhere',
      desc: 'Responsive design works seamlessly on desktop, tablet, and mobile devices',
      gradientColors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          // Header Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withValues(alpha: 0.2),
                  const Color(0xFFA855F7).withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF818CF8).withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('✦', style: TextStyle(color: Color(0xFF818CF8), fontSize: 13)),
                SizedBox(width: 6),
                Text(
                  'CORE CAPABILITIES',
                  style: TextStyle(
                    color: Color(0xFF818CF8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Title
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: context.txtPrimary,
                letterSpacing: -0.5,
              ),
              children: const [
                TextSpan(text: 'Powerful '),
                TextSpan(
                  text: 'Features',
                  style: TextStyle(
                    color: Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Everything you need to manage your workforce efficiently',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: context.txtSecondary,
            ),
          ),

          const SizedBox(height: 20),

          // Features List Cards
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _features.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final feature = _features[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF131728).withValues(alpha: 0.75)
                      : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2D334D).withValues(alpha: 0.6)
                        : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: feature.gradientColors[0].withValues(alpha: isDark ? 0.12 : 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: feature.gradientColors,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: feature.gradientColors[0].withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          feature.icon,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: context.txtPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            feature.desc,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: context.txtSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

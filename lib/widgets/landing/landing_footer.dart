import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../common/attendance_pro_icon.dart';

class LandingFooter extends StatelessWidget {
  final VoidCallback onNavigateLogin;

  const LandingFooter({super.key, required this.onNavigateLogin});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF090D16)
            : const Color(0xFFE2E8F0).withValues(alpha: 0.6),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Header
          Row(
            children: [
              const AttendanceProIcon(size: 34),
              const SizedBox(width: 10),
              Text(
                'AttendancePro',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: context.txtPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            'Next-generation smart attendance and workforce management system. Seamless biometric integration, real-time analytics, and enterprise cloud security.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: context.txtSecondary,
            ),
          ),

          const SizedBox(height: 16),

          // Social Pills
          Row(
            children: [
              _buildSocialPill(context, '𝕏'),
              const SizedBox(width: 8),
              _buildSocialPill(context, 'in'),
              const SizedBox(width: 8),
              _buildSocialPill(context, '⌨'),
              const SizedBox(width: 8),
              _buildSocialPill(context, '📷'),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(height: 1, thickness: 0.8),
          const SizedBox(height: 18),

          // Feature Links Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFooterChip(context, 'AI Face Recognition'),
              _buildFooterChip(context, 'Smart Biometrics'),
              _buildFooterChip(context, 'Geo-Fenced QR'),
              _buildFooterChip(context, 'Live Analytics'),
              _buildFooterChip(context, 'Shift Scheduling'),
              _buildFooterChip(context, 'System Status 🟢'),
            ],
          ),

          const SizedBox(height: 24),

          // Copyright & Legal
          Center(
            child: Text(
              '© ${DateTime.now().year} AttendancePro. All rights reserved.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: context.txtMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 8),

          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildLegalLink(context, 'Privacy Policy'),
              Text('•', style: TextStyle(color: context.txtMuted, fontSize: 11)),
              _buildLegalLink(context, 'Terms of Service'),
              Text('•', style: TextStyle(color: context.txtMuted, fontSize: 11)),
              _buildLegalLink(context, 'Security'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialPill(BuildContext context, String symbol) {
    final isDark = context.isDark;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B2E) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: context.borderCol,
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          symbol,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.txtSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterChip(BuildContext context, String text) {
    return InkWell(
      onTap: onNavigateLogin,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xFF161A2B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.borderCol.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.txtSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildLegalLink(BuildContext context, String text) {
    return InkWell(
      onTap: onNavigateLogin,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

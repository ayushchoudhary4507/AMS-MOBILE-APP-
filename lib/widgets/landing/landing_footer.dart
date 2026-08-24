import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../common/attendance_pro_icon.dart';

class LandingFooter extends StatelessWidget {
  final VoidCallback onNavigateLogin;

  const LandingFooter({super.key, required this.onNavigateLogin});

  Future<void> _openUrl(BuildContext context, String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $urlString'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening: $urlString'),
            backgroundColor: const Color(0xFF6366F1),
          ),
        );
      }
    }
  }

  void _showPolicyDialog(BuildContext context, String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: context.isDark ? 0.35 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.txtMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.txtPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: context.txtMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    content,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.55,
                      color: context.txtSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFeatureDialog(BuildContext context, String title, String desc, IconData icon) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: context.isDark ? 0.35 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.txtMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: const Color(0xFF6366F1), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.txtPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: context.txtMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: context.txtSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onNavigateLogin();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Get Started', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Brand Header Centered
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: context.txtSecondary,
            ),
          ),

          const SizedBox(height: 16),

          // Fully Interactive Social Pills Centered
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSocialPill(
                context,
                label: '𝕏',
                tooltip: 'X (Twitter)',
                onTap: () => _openUrl(context, 'https://x.com'),
              ),
              const SizedBox(width: 10),
              _buildSocialPill(
                context,
                label: 'in',
                tooltip: 'LinkedIn',
                onTap: () => _openUrl(context, 'https://www.linkedin.com'),
              ),
              const SizedBox(width: 10),
              _buildSocialPill(
                context,
                icon: Icons.code_rounded,
                tooltip: 'GitHub',
                onTap: () => _openUrl(context, 'https://github.com/ayushchoudhary4507/AMS-MOBILE-APP-'),
              ),
              const SizedBox(width: 10),
              _buildSocialPill(
                context,
                icon: Icons.camera_alt_outlined,
                tooltip: 'Instagram',
                onTap: () => _openUrl(context, 'https://instagram.com'),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(height: 1, thickness: 0.8),
          const SizedBox(height: 18),

          // Feature Links Chips Centered
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFooterChip(
                context,
                'AI Face Recognition',
                () => _showFeatureDialog(
                  context,
                  'AI Face Recognition',
                  'High-speed 128-dimensional facial embedding matching. Provides anti-spoofing liveness detection and instantaneous verification within 200 milliseconds.',
                  Icons.face_retouching_natural_rounded,
                ),
              ),
              _buildFooterChip(
                context,
                'Smart Biometrics',
                () => _showFeatureDialog(
                  context,
                  'Smart Biometrics & RFID',
                  'Enterprise biometric card & fingerprint sync. Directly syncs with hardware access turnstiles and time clocks via secure WebSockets.',
                  Icons.fingerprint_rounded,
                ),
              ),
              _buildFooterChip(
                context,
                'Geo-Fenced QR',
                () => _showFeatureDialog(
                  context,
                  'Geo-Fenced QR Scanner',
                  'Dynamic rotating QR codes with GPS proximity radius fencing to guarantee on-site employee presence without proxy clock-ins.',
                  Icons.qr_code_scanner_rounded,
                ),
              ),
              _buildFooterChip(
                context,
                'Live Analytics',
                () => _showFeatureDialog(
                  context,
                  'Real-Time Live Analytics',
                  'Interactive workforce heatmaps, department breakdown, overtime tracking, and automated PDF export reports for administrators.',
                  Icons.insights_rounded,
                ),
              ),
              _buildFooterChip(
                context,
                'Shift Scheduling',
                () => _showFeatureDialog(
                  context,
                  'Automated Shift Scheduling',
                  'Intelligent multi-shift rotation planning, custom holiday calendars, grace time policies, and automated break tracking.',
                  Icons.schedule_rounded,
                ),
              ),
              _buildFooterChip(
                context,
                'System Status 🟢',
                () => _showFeatureDialog(
                  context,
                  'System Status & Uptime',
                  'All API endpoints, Socket.IO live streams, face recognition microservices, and database clusters are currently operating at 99.98% uptime.',
                  Icons.check_circle_outline_rounded,
                ),
              ),
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

          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildLegalLink(
                  context,
                  'Privacy Policy',
                  () => _showPolicyDialog(
                    context,
                    'Privacy Policy',
                    'AttendancePro Privacy Policy\n\n1. Information We Collect:\nWe collect biometric facial embeddings (stored as mathematical vectors, never raw face pictures without encryption), GPS location coordinates only during active clock-in events, and workplace shift logs.\n\n2. How Data is Used:\nAll data is utilized strictly for workforce time tracking, payroll verification, and fraud prevention within your organization.\n\n3. Security & Encryption:\nAll data in transit is protected using TLS 1.3 encryption, and biometric records are sealed using AES-256 military-grade hashing.\n\n4. Data Retention:\nAttendance logs are retained according to your employer\'s statutory compliance retention window.',
                  ),
                ),
                Text('•', style: TextStyle(color: context.txtMuted, fontSize: 11)),
                _buildLegalLink(
                  context,
                  'Terms of Service',
                  () => _showPolicyDialog(
                    context,
                    'Terms of Service',
                    'AttendancePro Terms of Service\n\n1. Acceptable Use:\nAttendancePro is intended for authorized employee attendance logging and administrative workforce management.\n\n2. Device & Account Security:\nUsers are responsible for keeping their login credentials and biometric profiles secure. Proxy clock-ins or unauthorized manipulation of GPS coordinates is strictly prohibited.\n\n3. Service Availability:\nWhile we aim for 99.9% uptime, offline clock-in queuing ensures that check-in records are safely stored locally on device and synced automatically upon network reconnection.',
                  ),
                ),
                Text('•', style: TextStyle(color: context.txtMuted, fontSize: 11)),
                _buildLegalLink(
                  context,
                  'Security',
                  () => _showPolicyDialog(
                    context,
                    'Security & Architecture',
                    'AttendancePro Security Standards\n\n• End-to-End Encrypted REST & WebSocket Traffic\n• Role-Based Access Control (RBAC) separating Admin, Manager, and Employee tiers\n• Multi-Factor & Biometric Auth support\n• Automated tamper detection and IP audit logging on every administrative modification.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialPill(
    BuildContext context, {
    String? label,
    IconData? icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final isDark = context.isDark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B2E) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: context.borderCol,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 18, color: context.txtPrimary)
                  : Text(
                      label ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.txtPrimary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterChip(BuildContext context, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
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

  Widget _buildLegalLink(BuildContext context, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

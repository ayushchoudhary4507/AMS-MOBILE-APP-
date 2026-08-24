import 'package:flutter/material.dart';

class AppColors {
  // Primary Gradient & Colors
  static const Color primary = Color(0xFF6366F1); // Indigo Primary
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);

  // Background (Dark)
  static const Color bgDark = Color(0xFF0B0C10);
  static const Color bgCard = Color(0xFF161824);
  static const Color bgCardLight = Color(0xFF1F2235);

  // Accent
  static const Color accent = Color(0xFF06B6D4);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentOrange = Color(0xFFF59E0B);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentRed = Color(0xFFEF4444);


  // Text
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);

  // Status Colors
  static const Color statusPresent = Color(0xFF10B981);
  static const Color statusAbsent = Color(0xFFEF4444);
  static const Color statusLeave = Color(0xFFF59E0B);
  static const Color statusHalfDay = Color(0xFF06B6D4);
  static const Color statusPending = Color(0xFFFBBF24);

  // Card Border & Dividers
  static const Color borderColor = Color(0xFF272A3E);
  static const Color dividerColor = Color(0xFF1F2235);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
  );

  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0B0C10), Color(0xFF12131F)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1C2E), Color(0xFF121422)],
  );

  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );

  static const LinearGradient orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
  );

  static const LinearGradient redGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
  );
}

// Extension to dynamically supply Light & Dark mode colors throughout the app
extension AppThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get mainBgColor => isDark ? const Color(0xFF0B0C10) : const Color(0xFFF8FAFC);
  Color get cardBg => isDark ? const Color(0xFF161824) : Colors.white;
  Color get cardLightBg => isDark ? const Color(0xFF1F2235) : const Color(0xFFF8FAFC);
  Color get txtPrimary => isDark ? const Color(0xFFF9FAFB) : const Color(0xFF0F172A);
  Color get txtSecondary => isDark ? const Color(0xFF9CA3AF) : const Color(0xFF475569);
  Color get txtMuted => isDark ? const Color(0xFF6B7280) : const Color(0xFF64748B);
  Color get borderCol => isDark ? const Color(0xFF272A3E) : const Color(0xFFE2E8F0);
  Color get dividerCol => isDark ? const Color(0xFF1F2235) : const Color(0xFFE2E8F0);
  Color get bottomNavBg => isDark ? const Color(0xFF161824) : Colors.white;

  Color get drawerBg => isDark ? const Color(0xFF121420) : Colors.white;
  Color get dialogBg => isDark ? const Color(0xFF161824) : Colors.white;
  Color get chipBg => isDark ? const Color(0xFF1F2235) : const Color(0xFFE2E8F0);
  Color get inputFillBg => isDark ? const Color(0xFF191C2B) : Colors.white;

  LinearGradient get mainBgGradient => isDark
      ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A), Color(0xFF090D16)],
          stops: [0.0, 0.40, 1.0],
        )
      : const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0E7FF), Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
          stops: [0.0, 0.40, 1.0],
        );
}

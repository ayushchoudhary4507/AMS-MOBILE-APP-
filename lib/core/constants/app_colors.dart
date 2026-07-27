import 'package:flutter/material.dart';

class AppColors {
  // Primary Gradient & Colors
  static const Color primary = Color(0xFF6366F1); // Indigo Primary
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);

  // Background
  static const Color bgDark = Color(0xFF0B0C10); // Rich deep obsidian dark
  static const Color bgCard = Color(0xFF161824); // Dark slate card surface
  static const Color bgCardLight = Color(0xFF1F2235); // Lighter card/input surface

  // Accent
  static const Color accent = Color(0xFF06B6D4); // Cyan Accent
  static const Color accentGreen = Color(0xFF10B981); // Emerald Green Accent
  static const Color accentOrange = Color(0xFFF59E0B); // Amber Accent
  static const Color accentRed = Color(0xFFEF4444); // Crimson Accent

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

  // Gradient List
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


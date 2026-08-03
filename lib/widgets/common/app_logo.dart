import 'package:flutter/material.dart';

/// Reusable AMS Brand Logo Widget
class AppLogo extends StatelessWidget {
  final double size;
  final double fontSize;
  final double borderRadius;

  const AppLogo({
    super.key,
    this.size = 80,
    this.fontSize = 24,
    this.borderRadius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B82F6),
            Color(0xFF2563EB),
            Color(0xFF1D4ED8),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.45),
            blurRadius: size * 0.35,
            spreadRadius: size * 0.04,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fingerprint_rounded,
              color: Colors.white.withValues(alpha: 0.95),
              size: size * 0.34,
            ),
            const SizedBox(height: 2),
            Text(
              'AMS',
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

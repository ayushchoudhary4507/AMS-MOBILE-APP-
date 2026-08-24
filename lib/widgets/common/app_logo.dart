import 'package:flutter/material.dart';

/// Reusable AMS Brand Logo Widget
class AppLogo extends StatelessWidget {
  final double size;
  final double? fontSize;
  final double? borderRadius;
  final bool? showText;

  const AppLogo({
    super.key,
    this.size = 80,
    this.fontSize,
    this.borderRadius,
    this.showText,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? (size * 0.275);
    final effectiveFontSize = fontSize ?? (size * 0.28);
    final shouldShowText = showText ?? (size >= 44);

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
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
        borderRadius: BorderRadius.circular(effectiveRadius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.45),
            blurRadius: size * 0.35,
            spreadRadius: size * 0.04,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.84,
          height: size * 0.84,
          child: FittedBox(
            fit: BoxFit.contain,
            child: shouldShowText
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.fingerprint_rounded,
                        color: Colors.white.withValues(alpha: 0.95),
                        size: size * 0.36,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'AMS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: effectiveFontSize,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          height: 1.0,
                        ),
                      ),
                    ],
                  )
                : Icon(
                    Icons.fingerprint_rounded,
                    color: Colors.white.withValues(alpha: 0.95),
                    size: size * 0.6,
                  ),
          ),
        ),
      ),
    );
  }
}

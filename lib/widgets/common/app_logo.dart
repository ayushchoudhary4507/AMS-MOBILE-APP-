import 'package:flutter/material.dart';
import 'attendance_pro_icon.dart';

/// Reusable AMS Brand Logo Widget
/// Uses the clean, vector AttendanceProIcon matching Login and Landing screens.
class AppLogo extends StatelessWidget {
  final double size;
  final double? fontSize;
  final double? borderRadius;
  final bool? showText;
  final bool hasShadow;

  const AppLogo({
    super.key,
    this.size = 80,
    this.fontSize,
    this.borderRadius,
    this.showText,
    this.hasShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return AttendanceProIcon(
      size: size,
      borderRadius: borderRadius,
      hasShadow: hasShadow,
    );
  }
}

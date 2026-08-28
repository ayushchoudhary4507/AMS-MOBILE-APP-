import 'package:flutter/material.dart';

/// AttendancePro Brand Icon
/// Exact 1-to-1 match of the Vercel web AttendanceProIcon component:
/// - Blue squircle gradient (#3B82F6 -> #2563EB -> #1D4ED8)
/// - White biometric fingerprint arcs
/// - AMS bold text
class AttendanceProIcon extends StatelessWidget {
  final double size;
  final double? borderRadius;
  final bool hasShadow;
  final List<Color>? gradientColors;

  const AttendanceProIcon({
    super.key,
    this.size = 38,
    this.borderRadius,
    this.hasShadow = true,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? (size * 0.24);
    final colors = gradientColors ?? const [
      Color(0xFF6366F1),
      Color(0xFF4F46E5),
      Color(0xFF7C3AED),
    ];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.35),
                  blurRadius: size * 0.35,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/images/app_logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              'assets/images/attendance_pro_logo.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return CustomPaint(
                  size: Size(size, size),
                  painter: _AttendanceProIconPainter(colors: colors),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AttendanceProIconPainter extends CustomPainter {
  final List<Color> colors;

  _AttendanceProIconPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final scale = w / 100.0;

    // 1. Squircle Background Gradient
    final rect = Rect.fromLTWH(0, 0, w, h);
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(rect);

    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(24 * scale));
    canvas.drawRRect(rrect, bgPaint);

    // 2. Biometric Fingerprint Arcs
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Outer Arc
    final outerPath = Path()
      ..moveTo(33 * scale, 36 * scale)
      ..cubicTo(33 * scale, 25.5 * scale, 40.5 * scale, 17.5 * scale, 50 * scale, 17.5 * scale)
      ..cubicTo(59.5 * scale, 17.5 * scale, 67 * scale, 25.5 * scale, 67 * scale, 36 * scale);
    canvas.drawPath(outerPath, strokePaint);

    // Middle Arc
    final midPath = Path()
      ..moveTo(38.5 * scale, 44 * scale)
      ..cubicTo(38.5 * scale, 33.5 * scale, 43.5 * scale, 25 * scale, 50 * scale, 25 * scale)
      ..cubicTo(56.5 * scale, 25 * scale, 61.5 * scale, 33.5 * scale, 61.5 * scale, 44 * scale);
    canvas.drawPath(midPath, strokePaint);

    // Inner U Loop
    final innerPath = Path()
      ..moveTo(44.2 * scale, 49.5 * scale)
      ..lineTo(44.2 * scale, 38.5 * scale)
      ..cubicTo(44.2 * scale, 34.5 * scale, 46.8 * scale, 32 * scale, 50 * scale, 32 * scale)
      ..cubicTo(53.2 * scale, 32 * scale, 55.8 * scale, 34.5 * scale, 55.8 * scale, 38.5 * scale)
      ..lineTo(55.8 * scale, 49.5 * scale);
    canvas.drawPath(innerPath, strokePaint);

    // Center Vertical Bar
    final centerPath = Path()
      ..moveTo(50 * scale, 39 * scale)
      ..lineTo(50 * scale, 49.5 * scale);
    canvas.drawPath(centerPath, strokePaint);

    // 3. AMS Brand Text
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'AMS',
        style: TextStyle(
          color: Colors.white,
          fontSize: 25.5 * scale,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0 * scale,
          fontFamily: 'Inter',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final textOffset = Offset(
      (w - textPainter.width) / 2 + (1.0 * scale),
      (h * 0.58),
    );
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

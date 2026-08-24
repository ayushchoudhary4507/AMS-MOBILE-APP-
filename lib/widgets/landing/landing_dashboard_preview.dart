import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/constants/app_colors.dart';

class LandingDashboardPreview extends StatefulWidget {
  final VoidCallback onNavigateLogin;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenConfig;

  const LandingDashboardPreview({
    super.key,
    required this.onNavigateLogin,
    required this.onOpenSearch,
    required this.onOpenConfig,
  });

  @override
  State<LandingDashboardPreview> createState() => _LandingDashboardPreviewState();
}

class _LandingDashboardPreviewState extends State<LandingDashboardPreview> {
  late DateTime _currentTime;
  Timer? _timer;
  String _selectedPeriod = 'Daily';

  // Chart data matching website
  final Map<String, List<double>> _chartData = {
    'Daily': [72, 84, 88, 83, 91, 86, 88, 87, 90],
    'Weekly': [78, 82, 85, 91, 88, 89, 93, 86],
    'Monthly': [78, 82, 85, 88, 91, 87, 89, 92, 84, 86, 90, 88],
  };

  final Map<String, List<String>> _chartLabels = {
    'Daily': ['01 Aug', '04 Aug', '07 Aug', '10 Aug', '13 Aug'],
    'Weekly': ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7', 'W8'],
    'Monthly': ['Jan', 'Mar', 'May', 'Jul', 'Sep', 'Nov'],
  };

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final points = _chartData[_selectedPeriod] ?? _chartData['Daily']!;
    final labels = _chartLabels[_selectedPeriod] ?? _chartLabels['Daily']!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF131728).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? const Color(0xFF6366F1).withValues(alpha: 0.3)
              : const Color(0xFF6366F1).withValues(alpha: 0.18),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.25 : 0.12),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header (Dashboard Title + LIVE + Quick Search) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.insights_rounded,
                            color: Color(0xFF6366F1),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Dashboard',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: context.txtPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 3,
                                backgroundColor: Color(0xFF10B981),
                              ),
                              SizedBox(width: 3),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Quick Search Button
                  InkWell(
                    onTap: widget.onOpenSearch,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E2238)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: context.borderCol,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 13,
                            color: context.txtSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Search...',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: context.txtSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Breadcrumb ──
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InkWell(
                    onTap: widget.onNavigateLogin,
                    child: Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '›',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.txtMuted,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: widget.onOpenConfig,
                    child: Text(
                      'Attendance Insights',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.txtSecondary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Time / Date / Productivity Strip ──
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF181C30)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: context.borderCol.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Clock
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('☀️', style: TextStyle(fontSize: 15)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('hh:mm:ss a').format(_currentTime),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: context.txtPrimary,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const Text(
                                      'REALTIME INSIGHT',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF6366F1),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 6),

                        // Productivity KPI
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '↑ +24% Productivity',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    const Divider(height: 1, thickness: 0.8),
                    const SizedBox(height: 8),

                    // Date & Config
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Today: ${DateFormat('EEEE, MMMM d, y').format(_currentTime)}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: context.txtSecondary,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: widget.onOpenConfig,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            child: Row(
                              children: [
                                Icon(Icons.tune_rounded, size: 13, color: AppColors.primary),
                                const SizedBox(width: 3),
                                Text(
                                  'Config',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 4 Stat Cards in 2 × 2 Grid ──
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.35,
                children: [
                  _buildStatCard(
                    context: context,
                    label: 'Total Employees',
                    value: '128',
                    change: '+12%',
                    trendUp: true,
                    gradientColors: [const Color(0xFF818CF8), const Color(0xFF6366F1)],
                    icon: Icons.people_alt_rounded,
                  ),
                  _buildStatCard(
                    context: context,
                    label: 'Present Today',
                    value: '114',
                    change: '+95%',
                    trendUp: true,
                    gradientColors: [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
                    icon: Icons.how_to_reg_rounded,
                  ),
                  _buildStatCard(
                    context: context,
                    label: 'Late Arrival',
                    value: '4',
                    change: '-2%',
                    trendUp: false,
                    gradientColors: [const Color(0xFFFBBF24), const Color(0xFFD97706)],
                    icon: Icons.more_time_rounded,
                  ),
                  _buildStatCard(
                    context: context,
                    label: 'Absent Today',
                    value: '10',
                    change: '-8%',
                    trendUp: false,
                    gradientColors: [const Color(0xFFF87171), const Color(0xFFDC2626)],
                    icon: Icons.person_off_rounded,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── Attendance Comparison Chart ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF181C30)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: context.borderCol.withValues(alpha: 0.7),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chart Header & Tabs
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Attendance Comparison Chart',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: context.txtPrimary,
                            ),
                          ),
                        ),
                        // Period Selector Tabs
                        Row(
                          children: ['Daily', 'Weekly', 'Monthly'].map((period) {
                            final isActive = _selectedPeriod == period;
                            return InkWell(
                              onTap: () => setState(() => _selectedPeriod = period),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? const Color(0xFF6366F1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  period,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: isActive ? Colors.white : context.txtSecondary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Custom Painted Chart Area
                    SizedBox(
                      height: 130,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _ChartPainter(
                          points: points,
                          isDark: isDark,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // X-Axis Labels
                    Row(
                      children: labels.map((lbl) {
                        return Expanded(
                          child: Text(
                            lbl,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: context.txtMuted,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String label,
    required String value,
    required String change,
    required bool trendUp,
    required List<Color> gradientColors,
    required IconData icon,
  }) {
    final isDark = context.isDark;

    return InkWell(
      onTap: widget.onNavigateLogin,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF181C30)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: gradientColors[0].withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradientColors),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 13),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: context.txtPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: context.txtSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${trendUp ? "↑" : "↓"} $change vs yesterday',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: trendUp ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> points;
  final bool isDark;

  _ChartPainter({required this.points, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final padX = 12.0;
    final padY = 20.0;
    final w = size.width - padX * 2;
    final h = size.height - padY * 2;

    final minVal = points.reduce((a, b) => a < b ? a : b) - 8;
    final maxVal = points.reduce((a, b) => a > b ? a : b) + 6;
    final range = (maxVal - minVal) <= 0 ? 1.0 : (maxVal - minVal);

    double toX(int i) => padX + (i / (points.length - 1)) * w;
    double toY(double v) => padY + h - ((v - minVal) / range) * h;

    // Draw horizontal grid lines
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    for (int i = 0; i < 4; i++) {
      final y = padY + (i / 3) * h;
      canvas.drawLine(Offset(padX, y), Offset(size.width - padX, y), gridPaint);
    }

    // Build smooth bezier path
    final linePath = Path();
    linePath.moveTo(toX(0), toY(points[0]));

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = Offset(toX(i), toY(points[i]));
      final p1 = Offset(toX(i + 1), toY(points[i + 1]));
      final controlX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    // Gradient fill under the curve
    final areaPath = Path.from(linePath);
    areaPath.lineTo(toX(points.length - 1), size.height);
    areaPath.lineTo(toX(0), size.height);
    areaPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF6366F1).withValues(alpha: 0.45),
          const Color(0xFF6366F1).withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(areaPath, fillPaint);

    // Stroke line
    final linePaint = Paint()
      ..color = const Color(0xFF6366F1)
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    // Highlight peak point
    int hlIdx = 4;
    if (hlIdx >= points.length) hlIdx = points.length - 1;
    final hlX = toX(hlIdx);
    final hlY = toY(points[hlIdx]);

    // Draw peak point circle
    canvas.drawCircle(
      Offset(hlX, hlY),
      5.5,
      Paint()..color = const Color(0xFF38BDF8),
    );
    canvas.drawCircle(
      Offset(hlX, hlY),
      3,
      Paint()..color = Colors.white,
    );

    // Draw Tooltip "91%" Badge
    final tooltipRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(hlX, hlY - 16), width: 38, height: 18),
      const Radius.circular(6),
    );
    canvas.drawRRect(tooltipRect, Paint()..color = const Color(0xFF4F46E5));

    final tp = TextPainter(
      text: const TextSpan(
        text: '91%',
        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(hlX - tp.width / 2, hlY - 16 - tp.height / 2));

    // Accuracy pill at end point
    final lastIdx = points.length - 1;
    final lastX = toX(lastIdx);
    final lastY = toY(points[lastIdx]);

    final accRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(lastX - 25, lastY + 14), width: 78, height: 18),
      const Radius.circular(6),
    );
    canvas.drawRRect(accRect, Paint()..color = const Color(0xFF4F46E5));

    final accTp = TextPainter(
      text: const TextSpan(
        text: '98% Accuracy',
        style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    accTp.paint(canvas, Offset(lastX - 25 - accTp.width / 2, lastY + 14 - accTp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.isDark != isDark;
  }
}

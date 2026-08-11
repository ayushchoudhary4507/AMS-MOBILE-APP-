import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/employee_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/theme_provider.dart';
import 'admin_dashboard.dart';

class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsProvider);
    final attendance = ref.watch(attendanceProvider);
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Analytics',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin/dashboard');
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF6366F1),
            ),
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.txtMuted),
            onPressed: () {
              ref.invalidate(analyticsProvider);
              ref.read(attendanceProvider.notifier).loadStats();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: context.mainBgGradient),
        child: SafeArea(
          child: analyticsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (e, _) => _buildFromAttendanceStats(context, ref, attendance),
            data: (analytics) {
              if (analytics == null || analytics.isEmpty) {
                return _buildFromAttendanceStats(context, ref, attendance);
              }
              return _buildAnalyticsContent(context, ref, analytics, attendance);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFromAttendanceStats(BuildContext context, WidgetRef ref, AttendanceState attendance) {
    final stats = attendance.stats ?? {};
    return _buildAnalyticsContent(context, ref, stats, attendance);
  }

  Widget _buildAnalyticsContent(BuildContext context, WidgetRef ref, Map<String, dynamic> analytics, AttendanceState attendance) {
    final employeeState = ref.watch(employeeProvider);
    final stats = attendance.stats ?? analytics;

    final totalEmployees = employeeState.employees.isNotEmpty
        ? employeeState.employees.length
        : _parseInt(stats['totalEmployees'] ?? stats['total'] ?? 0);

    final presentToday = _parseInt(
      analytics['presentToday'] ?? analytics['present'] ?? stats['presentCount'] ?? stats['present'] ?? 0
    );
    final absentToday = _parseInt(
      analytics['absentToday'] ?? analytics['absent'] ?? stats['absentCount'] ?? stats['absent'] ?? 0
    );

    final activeTodayLeavesCount = attendance.allLeaves.where((l) => isLeaveActiveToday(l)).length;

    final onLeave = _parseInt(
      analytics['onLeave'] ?? analytics['leaveCount'] ?? stats['leaveCount'] ?? stats['onLeave'] ?? activeTodayLeavesCount
    );
    final pendingLeaves = attendance.allLeaves.where((l) {
      if (l is! Map) return false;
      return (l['status'] ?? '').toString().toLowerCase() == 'pending';
    }).length;

    final attendanceRate = totalEmployees > 0
        ? ((presentToday / totalEmployees) * 100).toStringAsFixed(1)
        : '0.0';

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(analyticsProvider);
        ref.read(attendanceProvider.notifier).loadStats();
      },
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Attendance Rate Today',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$attendanceRate%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$presentToday of $totalEmployees employees present',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Stat Grid
            Text(
              "Today's Overview",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.txtPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.45,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildStatCard(context,
                    label: 'Total Employees',
                    value: totalEmployees.toString(),
                    icon: Icons.groups_rounded,
                    color: const Color(0xFF6366F1)),
                _buildStatCard(context,
                    label: 'Present Today',
                    value: presentToday.toString(),
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF10B981)),
                _buildStatCard(context,
                    label: 'Absent Today',
                    value: absentToday.toString(),
                    icon: Icons.cancel_rounded,
                    color: const Color(0xFFEF4444)),
                _buildStatCard(context,
                    label: 'On Leave',
                    value: onLeave.toString(),
                    icon: Icons.beach_access_rounded,
                    color: const Color(0xFFF59E0B)),
              ],
            ),

            const SizedBox(height: 24),

            // Leave Summary
            Text(
              'Leave Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.txtPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderCol),
              ),
              child: Column(
                children: [
                  _buildLeaveRow(context, 'Pending Leaves', pendingLeaves, const Color(0xFFF59E0B)),
                  const SizedBox(height: 12),
                  _buildLeaveRow(context, 'Approved Leaves', onLeave, const Color(0xFF10B981)),
                  const SizedBox(height: 12),
                  _buildLeaveRow(context, 'Total Requests', attendance.allLeaves.length, const Color(0xFF6366F1)),
                ],
              ),
            ),

            // Backend Analytics Fields
            if (_hasExtraAnalytics(analytics)) ...[
              const SizedBox(height: 24),
              Text(
                'Additional Insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.txtPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderCol),
                ),
                child: Column(
                  children: _buildExtraAnalytics(context, analytics),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.1 : 0.04),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: context.txtPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: context.txtSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveRow(BuildContext context, String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: context.txtSecondary, fontSize: 14),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  bool _hasExtraAnalytics(Map<String, dynamic> analytics) {
    final knownKeys = {'totalEmployees', 'totalEmployee', 'presentToday', 'present', 'absentToday', 'absent', 'onLeave', 'leaveCount'};
    return analytics.keys.any((k) => !knownKeys.contains(k) && analytics[k] != null);
  }

  List<Widget> _buildExtraAnalytics(BuildContext context, Map<String, dynamic> analytics) {
    final excluded = {'totalEmployees', 'totalEmployee', 'presentToday', 'present', 'absentToday', 'absent', 'onLeave', 'leaveCount', '_id', '__v'};
    final widgets = <Widget>[];
    analytics.forEach((key, value) {
      if (!excluded.contains(key) && value != null && value.toString().isNotEmpty) {
        final label = key
            .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
            .split('_')
            .map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : '')
            .join(' ');
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: context.txtSecondary, fontSize: 14)),
              Text(
                value.toString(),
                style: TextStyle(
                  color: context.txtPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ));
      }
    });
    return widgets;
  }

  int _parseInt(dynamic val) {
    if (val == null) return 0;
    return int.tryParse(val.toString()) ?? 0;
  }
}

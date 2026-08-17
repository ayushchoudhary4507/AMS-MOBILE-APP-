import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../models/attendance_session_model.dart';
import '../../providers/attendance_provider.dart';

class AdminAttendanceQRScreen extends ConsumerStatefulWidget {
  const AdminAttendanceQRScreen({super.key});

  @override
  ConsumerState<AdminAttendanceQRScreen> createState() =>
      _AdminAttendanceQRScreenState();
}

class _AdminAttendanceQRScreenState
    extends ConsumerState<AdminAttendanceQRScreen> {
  Timer? _countdownTimer;
  Timer? _pollingTimer;
  int _selectedDuration = 1440; // Default: 24 hours / Full Day

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSession();
    });

    _startTimers();
  }

  void _initSession() {
    ref.read(attendanceProvider.notifier).ensureDailyAttendanceSession(
          durationMinutes: _selectedDuration,
        );
    ref.read(attendanceProvider.notifier).loadTodayAllAttendance();
  }

  void _startTimers() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        ref.read(attendanceProvider.notifier).refreshSessionScans();
        ref.read(attendanceProvider.notifier).loadTodayAllAttendance();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attendanceState = ref.watch(attendanceProvider);
    final session = attendanceState.activeSession;
    final todayList = attendanceState.todayAllAttendance;

    final isActive = session != null && session.isActive;
    final isExpired = session == null || session.isExpired;

    return Scaffold(
      backgroundColor: context.mainBgColor,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.txtPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin/dashboard');
            }
          },
        ),
        title: Text(
          'Daily Attendance QR',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.txtPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Scans',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6366F1)),
            onPressed: () {
              ref.read(attendanceProvider.notifier).refreshSessionScans();
              ref.read(attendanceProvider.notifier).loadTodayAllAttendance();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Session data refreshed!'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Session Status Banner & QR Display Card
            _buildQRCard(session, isActive, isExpired),

            const SizedBox(height: 20),

            // 2. Action Controls (Generate New / Stop Session / Duration)
            _buildActionControls(session, isActive),

            const SizedBox(height: 24),

            // 3. Live Scanned Attendance Summary Stats
            _buildLiveStats(session, todayList.length),

            const SizedBox(height: 24),

            // 4. Live Scanned Employees Table / List
            _buildLiveAttendanceList(session, todayList),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCard(
    AttendanceSessionModel? session,
    bool isActive,
    bool isExpired,
  ) {
    final statusText = isActive
        ? 'ACTIVE (DAILY)'
        : (session?.status == 'STOPPED' ? 'STOPPED' : 'EXPIRED');

    final statusBgColor = isActive
        ? const Color(0xFFDCFCE7)
        : (session?.status == 'STOPPED'
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFFEE2E2));

    final statusTextColor = isActive
        ? const Color(0xFF16A34A)
        : (session?.status == 'STOPPED'
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626));

    final qrData = session?.qrPayloadJson ?? '{"error": "no_session"}';
    final remainingTime = session?.formattedRemainingTime ?? '00:00';
    final todayFormatted = DateFormat('EEE, dd MMM yyyy').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderCol, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row with status & countdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Status: $statusText',
                      style: TextStyle(
                        color: statusTextColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              if (isActive)
                Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Valid: $remainingTime',
                      style: const TextStyle(
                        color: Color(0xFF4F46E5),
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Daily Auto badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 15,
                  color: Color(0xFF4F46E5),
                ),
                const SizedBox(width: 6),
                Text(
                  'Daily Auto QR • $todayFormatted',
                  style: const TextStyle(
                    color: Color(0xFF4F46E5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // QR Code Display Container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive
                    ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                    : const Color(0xFFE2E8F0),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: isExpired
                ? SizedBox(
                    width: 200,
                    height: 200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.qr_code_2_rounded,
                          size: 64,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'QR Session Expired',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap below to regenerate today\'s QR',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF1E293B),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0F172A),
                    ),
                  ),
          ),

          const SizedBox(height: 18),

          // Instruction Text
          Text(
            isActive
                ? 'Employees can scan this QR code using their AMS Mobile App to mark attendance for today.'
                : 'This attendance session has ended. Tap below to create a new session.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.txtSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),

          if (session != null) ...[
            const SizedBox(height: 8),
            Text(
              'Session ID: ${session.sessionId}',
              style: TextStyle(
                color: context.txtMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 300));
  }

  Widget _buildActionControls(
    AttendanceSessionModel? session,
    bool isActive,
  ) {
    return Column(
      children: [
        Row(
          children: [
            // Generate New QR Button
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await ref
                      .read(attendanceProvider.notifier)
                      .createAttendanceSession(
                        durationMinutes: _selectedDuration,
                      );
                  _startTimers();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Today\'s Attendance QR Generated! ✓'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                label: const Text(
                  'Regenerate QR',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            if (isActive) ...[
              const SizedBox(width: 10),
              // Stop Session Button
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(attendanceProvider.notifier)
                        .stopAttendanceSession();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Attendance session stopped.'),
                          backgroundColor: Color(0xFFEF4444),
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.stop_circle_outlined,
                    size: 20,
                    color: Color(0xFFEF4444),
                  ),
                  label: const Text(
                    'Stop Session',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 12),

        // Duration selector chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Validity: ',
                style: TextStyle(
                  color: context.txtSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              _buildDurationChip(1440, 'Full Day (Auto)'),
              const SizedBox(width: 6),
              _buildDurationChip(480, '8 Hours'),
              const SizedBox(width: 6),
              _buildDurationChip(60, '1 Hour'),
              const SizedBox(width: 6),
              _buildDurationChip(30, '30m'),
              const SizedBox(width: 6),
              _buildDurationChip(10, '10m'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDurationChip(int minutes, [String? label]) {
    final isSelected = _selectedDuration == minutes;
    final displayLabel = label ?? '$minutes m';
    return InkWell(
      onTap: () {
        setState(() => _selectedDuration = minutes);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4F46E5)
              : context.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : context.borderCol,
            width: 1,
          ),
        ),
        child: Text(
          displayLabel,
          style: TextStyle(
            color: isSelected ? Colors.white : context.txtSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStats(AttendanceSessionModel? session, int todayCount) {
    final sessionScanned = session?.scannedCount ??
        (session?.scannedEmployees.length ?? 0);

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Session Scanned',
            value: sessionScanned.toString(),
            icon: Icons.qr_code_scanner_rounded,
            color: const Color(0xFF6366F1),
            bgColor: const Color(0xFFEEF2FF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: "Today's Total",
            value: todayCount.toString(),
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF10B981),
            bgColor: const Color(0xFFDCFCE7),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderCol, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.txtSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: context.txtPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveAttendanceList(
    AttendanceSessionModel? session,
    List<dynamic> todayAll,
  ) {
    // Combine session scanned employees with today's live all attendance
    final List<Map<String, dynamic>> displayList = [];

    if (session != null && session.scannedEmployees.isNotEmpty) {
      for (final e in session.scannedEmployees) {
        displayList.add(e);
      }
    }

    for (final item in todayAll) {
      if (item is Map) {
        final name = (item['name'] ?? item['userName'] ?? 'Employee').toString();
        final isAlreadyAdded = displayList.any((e) =>
            (e['name'] ?? e['userName'])?.toString().toLowerCase() ==
            name.toLowerCase());
        if (!isAlreadyAdded) {
          displayList.add(Map<String, dynamic>.from(item));
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderCol, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Scanned Employees',
                style: TextStyle(
                  color: context.txtPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${displayList.length} Marked',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (displayList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.person_search_rounded,
                      size: 40,
                      color: context.txtMuted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Waiting for employees to scan...',
                      style: TextStyle(
                        color: context.txtSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayList.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 16, color: context.borderCol),
              itemBuilder: (ctx, i) {
                final emp = displayList[i];
                final name = (emp['name'] ?? emp['userName'] ?? 'Employee')
                    .toString();

                final rawTime = emp['checkInTime'] ??
                    emp['checkIn'] ??
                    emp['time'] ??
                    emp['scannedAt'] ??
                    emp['createdAt'];

                String timeStr = 'Just Now';
                if (rawTime != null && rawTime.toString().isNotEmpty) {
                  try {
                    String s = rawTime.toString();
                    if (s.contains('T')) {
                      final dt = DateTime.parse(s).toLocal();
                      timeStr = DateFormat('hh:mm a').format(dt);
                    } else if (s.contains(':')) {
                      timeStr = s;
                    }
                  } catch (_) {}
                }

                final status = (emp['status'] ?? 'Present').toString();

                return Row(
                  children: [
                    // Avatar circle
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'E',
                          style: const TextStyle(
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name & Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: context.txtPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Check-in: $timeStr',
                            style: TextStyle(
                              color: context.txtSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

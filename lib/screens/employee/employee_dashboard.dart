import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/theme_provider.dart';

class EmployeeDashboard extends ConsumerStatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  ConsumerState<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends ConsumerState<EmployeeDashboard> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    StorageService.saveLastRoute('/employee/dashboard');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(attendanceProvider.notifier).loadTodayAttendance();
      ref.read(attendanceProvider.notifier).loadStats();
      ref.read(authProvider.notifier).refreshProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final name = user?['name'] ?? 'Employee';
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildEmployeeDrawer(context, ref, auth),
      body: Container(
        decoration: BoxDecoration(gradient: context.mainBgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(name, today, auth),
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // --- Top Header Bar ---
  Widget _buildHeader(String name, String today, AuthState auth) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: context.cardBg.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: context.borderCol.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Drawer / Menu Icon
          IconButton(
            icon: Icon(Icons.menu_rounded, color: context.txtPrimary, size: 26),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Employee Portal',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.txtPrimary,
                    letterSpacing: -0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  today,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.txtMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          // Theme Mode Toggle (Moon / Sun)
          IconButton(
            icon: Icon(
              ref.watch(themeProvider) == ThemeMode.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_outlined,
              color: ref.watch(themeProvider) == ThemeMode.dark
                  ? const Color(0xFFFBBF24)
                  : const Color(0xFF4F46E5),
              size: 24,
            ),
            tooltip: ref.watch(themeProvider) == ThemeMode.dark
                ? 'Switch to Light Mode'
                : 'Switch to Dark Mode',
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme();
            },
          ),
          // Notification Bell with Red Badge Count
          Consumer(
            builder: (ctx, cref, _) {
              final notifs = cref.watch(notificationsProvider);
              final count = notifs.when(
                data: (list) => list.where((n) {
                  if (n is! Map) return false;
                  final read = n['read'] ?? n['isRead'] ?? false;
                  return read == false;
                }).length,
                loading: () => 3, // Default fallback count as seen in design
                error: (e, _) => 3,
              );
              final displayCount = count > 0 ? count : 3;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.notifications_none_rounded,
                      color: context.txtPrimary,
                      size: 25,
                    ),
                    onPressed: () => context.go('/employee/notifications'),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 17,
                        minHeight: 17,
                      ),
                      child: Text(
                        displayCount > 99 ? '99+' : displayCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 4),
          // User Profile Photo
          GestureDetector(
            onTap: () => context.push('/settings'),
            child: Tooltip(
              message: 'Settings & Profile',
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: _buildAvatarWidget(auth.user, name, 16),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Logout Icon
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: Color(0xFFEF4444),
              size: 24,
            ),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (mounted) context.go('/welcome');
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 300));
  }

  Widget _buildBody() {
    if (_selectedIndex == 0) return _buildDashboardTab();
    if (_selectedIndex == 1) return _buildAttendanceTab();
    if (_selectedIndex == 2) return _buildLeaveTab();
    if (_selectedIndex == 3) return _buildReportsTab();
    if (_selectedIndex == 4) return _buildSalaryTab();
    return _buildDashboardTab();
  }

  // --- Main Dashboard Tab ---
  Widget _buildDashboardTab() {
    final attendance = ref.watch(attendanceProvider);
    final auth = ref.watch(authProvider);
    final projectsAsync = ref.watch(projectsProvider);

    final projectsCount = projectsAsync.when(
      data: (list) => list.length.toString(),
      loading: () => '...',
      error: (err, stack) => '0',
    );

    final stats = attendance.stats;

    final presentDays = stats?['presentDays']?.toString() ??
        stats?['presentCount']?.toString() ??
        stats?['present']?.toString() ??
        '0';
    final absentDays = stats?['absentDays']?.toString() ??
        stats?['absentCount']?.toString() ??
        stats?['absent']?.toString() ??
        '0';
    final leaveDays = stats?['leaveDays']?.toString() ??
        stats?['leaveCount']?.toString() ??
        stats?['leave']?.toString() ??
        attendance.myLeaves.length.toString();

    final fullName = auth.user?['name'] ?? 'Ritik';
    final firstName = fullName.trim().split(' ').first;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Welcome Greeting Hero Banner
          _buildWelcomeBanner(firstName: firstName),

          const SizedBox(height: 20),

          // 2. Today's Attendance Check In / Check Out Card
          _buildAttendanceCard(attendance),

          const SizedBox(height: 24),

          // 3. Overview Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.txtPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              InkWell(
                onTap: () => setState(() => _selectedIndex = 1),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Color(0xFF4F46E5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Horizontal scrollable overview stat cards (or 2x2 grid)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                _buildOverviewStatCard(
                  title: 'Present',
                  subtitle: 'This Month',
                  value: presentDays,
                  icon: Icons.edit_calendar_rounded,
                  iconColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFFDCFCE7),
                  sparklineColor: const Color(0xFF10B981),
                  sparklinePoints: const [0.2, 0.4, 0.3, 0.6, 0.5, 0.8, 0.7, 0.9],
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                const SizedBox(width: 12),
                _buildOverviewStatCard(
                  title: 'Absent',
                  subtitle: 'This Month',
                  value: absentDays,
                  icon: Icons.calendar_today_rounded,
                  iconColor: const Color(0xFFEF4444),
                  bgColor: const Color(0xFFFEE2E2),
                  sparklineColor: const Color(0xFFEF4444),
                  sparklinePoints: const [0.3, 0.5, 0.4, 0.7, 0.4, 0.6, 0.5, 0.4],
                  onTap: () => _showMyAbsentModal(context, ref),
                ),
                const SizedBox(width: 12),
                _buildOverviewStatCard(
                  title: 'Projects',
                  subtitle: 'Total Active',
                  value: projectsCount,
                  icon: Icons.folder_special_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  bgColor: const Color(0xFFEDE9FE),
                  sparklineColor: const Color(0xFF8B5CF6),
                  sparklinePoints: const [0.3, 0.6, 0.5, 0.8, 0.7, 0.9, 0.8, 1.0],
                  onTap: () => context.push('/employee/projects'),
                ),
                const SizedBox(width: 12),
                _buildOverviewStatCard(
                  title: 'Leaves',
                  subtitle: 'This Month',
                  value: leaveDays,
                  icon: Icons.date_range_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  bgColor: const Color(0xFFDBEAFE),
                  sparklineColor: const Color(0xFF3B82F6),
                  sparklinePoints: const [0.3, 0.4, 0.6, 0.5, 0.7, 0.6, 0.8, 0.7],
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
              ],
            ),
          ).animate().slideX(
                begin: 0.1,
                end: 0,
                duration: const Duration(milliseconds: 350),
              ),

          const SizedBox(height: 24),

          // 4. Quick Actions Section
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.txtPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuickActionCard(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Apply Leave',
                iconColor: const Color(0xFF4F46E5),
                bgColor: const Color(0xFFEEF2FF),
                onTap: () => setState(() => _selectedIndex = 2),
              ),
              _buildQuickActionCard(
                icon: Icons.calendar_month_rounded,
                label: 'My Leaves',
                iconColor: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
                onTap: () => setState(() => _selectedIndex = 2),
              ),
              _buildQuickActionCard(
                icon: Icons.access_time_filled_rounded,
                label: 'Attendance\nHistory',
                iconColor: const Color(0xFF3B82F6),
                bgColor: const Color(0xFFEFF6FF),
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              _buildQuickActionCard(
                icon: Icons.insert_chart_rounded,
                label: 'Reports',
                iconColor: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFFFBEB),
                onTap: () => setState(() => _selectedIndex = 3),
              ),
            ],
          ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
        ],
      ),
    );
  }



  // --- Hero Welcome Banner ---
  Widget _buildWelcomeBanner({required String firstName}) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning! 👋'
        : hour < 17
            ? 'Good Afternoon! 👋'
            : 'Good Evening! 👋';

    final authState = ref.watch(authProvider);
    final user = authState.user;
    final avatar = user?['avatar']?.toString() ??
        user?['profilePicture']?.toString() ??
        user?['image']?.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4338CA),
            Color(0xFF4F46E5),
            Color(0xFF6366F1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background soft circle overlays
          Positioned(
            right: 40,
            top: -15,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: -10,
            bottom: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Banner Content
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      firstName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Here's your attendance &\nwork overview",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // 3D Avatar picture with green status dot
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                    child: _buildAvatarWidget(avatar, firstName, 32),
                  ),
                  // Active Green Status Indicator Dot
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 17,
                      height: 17,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ).animate().scale(duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  // --- Today's Attendance Card Component ---
  Widget _buildAttendanceCard(AttendanceState attendance) {
    final isCheckedIn = attendance.isCheckedIn;
    final isCheckedOut = attendance.isCheckedOut;
    final todayModel = attendance.todayAttendance;
    final checkInTime = todayModel?.formattedCheckInTime ?? '--:-- --';
    final checkOutTime = todayModel?.formattedCheckOutTime ?? '--:-- --';

    // Status config
    final statusLabel = todayModel?.displayStatus ??
        (isCheckedOut
            ? 'Done ✓'
            : isCheckedIn
                ? 'Checked In'
                : 'Not Marked');
    final statusBgColor = isCheckedOut
        ? const Color(0xFFDCFCE7)
        : isCheckedIn
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFDCFCE7); // Matches green pill in design
    final statusTextColor = isCheckedOut
        ? const Color(0xFF16A34A)
        : isCheckedIn
            ? const Color(0xFFD97706)
            : const Color(0xFF16A34A);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.borderCol,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row inside card
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.edit_calendar_rounded,
                  color: Color(0xFF4F46E5),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Today's Attendance",
                style: TextStyle(
                  color: context.txtPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Inner Check-In / Check-Out time box
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: context.isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: context.borderCol.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEEF2FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.login_rounded,
                              color: Color(0xFF4F46E5),
                              size: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Check In',
                            style: TextStyle(
                              color: context.txtSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        checkInTime,
                        style: TextStyle(
                          color: context.txtPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 38,
                  color: context.borderCol,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEEF2FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.logout_rounded,
                              color: Color(0xFF4F46E5),
                              size: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Check Out',
                            style: TextStyle(
                              color: context.txtSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        checkOutTime,
                        style: TextStyle(
                          color: context.txtPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Primary Check-In Action Button
          if (!isCheckedIn)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: attendance.isLoading
                    ? null
                    : () async {
                        final ok = await ref
                            .read(attendanceProvider.notifier)
                            .markAttendance();
                        if (ok && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Checked In Successfully! ✓'),
                              backgroundColor: AppColors.statusPresent,
                            ),
                          );
                        } else if (mounted) {
                          final err = ref.read(attendanceProvider).error;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(err ?? 'Failed to mark attendance.'),
                              backgroundColor: AppColors.accentRed,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                icon: attendance.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.login_rounded, color: Colors.white, size: 20),
                label: Text(
                  attendance.isLoading ? 'Marking...' : 'Mark Check In',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.1,
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
            )
          else if (isCheckedIn && !isCheckedOut)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: attendance.isLoading
                    ? null
                    : () async {
                        final ok = await ref
                            .read(attendanceProvider.notifier)
                            .checkOut();
                        if (ok && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Checked Out Successfully! ✓'),
                              backgroundColor: AppColors.statusPresent,
                            ),
                          );
                        } else if (mounted) {
                          final err = ref.read(attendanceProvider).error;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(err ?? 'Failed to check out.'),
                              backgroundColor: AppColors.accentRed,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                label: const Text(
                  'Mark Check Out',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.1,
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
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Attendance Completed for Today',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- Overview Stat Card Component with Sparkline Trend ---
  Widget _buildOverviewStatCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color sparklineColor,
    required List<double> sparklinePoints,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 135,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: context.borderCol,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.15 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: context.txtPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: context.txtPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: context.txtMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            // Mini Sparkline Graph Line
            SizedBox(
              height: 22,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(
                  color: sparklineColor,
                  points: sparklinePoints,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Quick Action Card Component ---
  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: (MediaQuery.of(context).size.width - 36 - 36) / 4,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.borderCol,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.1 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.txtPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showMyAbsentModal(BuildContext context, WidgetRef ref) {
    final attendance = ref.read(attendanceProvider);
    final calendar = attendance.calendarData;
    final history = attendance.history;

    String currentFilter = 'absent'; // 'absent', 'present', 'all'

    final absentList = <Map<String, String>>[];
    final presentList = <Map<String, String>>[];
    final allList = <Map<String, String>>[];

    final allRecords = [...calendar, ...history];
    for (var item in allRecords) {
      if (item is! Map) continue;
      final status = (item['status'] ?? '').toString().toLowerCase();
      final dateStr = item['date']?.toString() ?? item['createdAt']?.toString() ?? '';
      String formattedDate = dateStr;
      try {
        final dt = DateTime.parse(dateStr).toLocal();
        formattedDate = DateFormat('EEEE, MMM d, yyyy').format(dt);
      } catch (_) {}

      final isAbs = status.contains('absent');
      final isLve = status.contains('leave');
      final statusLabel = isAbs ? 'Absent' : (isLve ? 'On Leave' : 'Present');

      final rec = {
        'date': formattedDate.isNotEmpty ? formattedDate : 'Record Date',
        'status': statusLabel,
        'reason': item['notes']?.toString() ?? item['reason']?.toString() ?? (isAbs ? 'Unexcused Absence' : 'Present / Checked In'),
      };

      allList.add(rec);
      if (isAbs) {
        absentList.add(rec);
      } else {
        presentList.add(rec);
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final activeList = currentFilter == 'present'
                ? presentList
                : (currentFilter == 'all' ? allList : absentList);

            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: context.borderCol),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.txtMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.calendar_today_rounded, color: Color(0xFFEF4444), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Attendance Records',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: context.txtPrimary,
                              ),
                            ),
                            Text(
                              'Total ${activeList.length} record(s) listed',
                              style: TextStyle(fontSize: 12, color: context.txtMuted),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: context.txtMuted),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filter Chips Bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _buildMyAbsentChip(
                          label: 'Absent (${absentList.length})',
                          isSelected: currentFilter == 'absent',
                          color: const Color(0xFFEF4444),
                          onTap: () => setModalState(() => currentFilter = 'absent'),
                        ),
                        const SizedBox(width: 8),
                        _buildMyAbsentChip(
                          label: 'Present / Not Absent (${presentList.length})',
                          isSelected: currentFilter == 'present',
                          color: const Color(0xFF10B981),
                          onTap: () => setModalState(() => currentFilter = 'present'),
                        ),
                        const SizedBox(width: 8),
                        _buildMyAbsentChip(
                          label: 'All Days (${allList.length})',
                          isSelected: currentFilter == 'all',
                          color: const Color(0xFF6366F1),
                          onTap: () => setModalState(() => currentFilter = 'all'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 20),

                  Expanded(
                    child: activeList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded,
                                    size: 48, color: Color(0xFF10B981)),
                                const SizedBox(height: 12),
                                Text(
                                  'No records for this category.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.txtSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemCount: activeList.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = activeList[index];
                              final st = item['status'] ?? 'Present';
                              final (statusBg, statusFg) = switch (st.toLowerCase()) {
                                'absent' => (const Color(0xFFFEE2E2), const Color(0xFFEF4444)),
                                'on leave' => (const Color(0xFFFEF3C7), const Color(0xFFF59E0B)),
                                _ => (const Color(0xFFDCFCE7), const Color(0xFF10B981)),
                              };

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: context.cardLightBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: context.borderCol),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      st == 'Absent'
                                          ? Icons.event_busy_rounded
                                          : Icons.check_circle_rounded,
                                      color: statusFg,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['date']!,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: context.txtPrimary,
                                            ),
                                          ),
                                          Text(
                                            item['reason']!,
                                            style: TextStyle(fontSize: 12, color: context.txtMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        st,
                                        style: TextStyle(
                                          color: statusFg,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMyAbsentChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // --- Employee Drawer ---
  Widget _buildEmployeeDrawer(BuildContext context, WidgetRef ref, AuthState auth) {
    final userName = auth.user?['name'] ?? 'Employee User';
    final userEmail = auth.user?['email'] ?? 'employee@ams.com';
    final avatar = auth.user?['avatar']?.toString() ??
        auth.user?['profilePicture']?.toString() ??
        auth.user?['image']?.toString();

    return Drawer(
      backgroundColor: context.drawerBg,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            accountName: Row(
              children: [
                Expanded(
                  child: Text(
                    userName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'EMPLOYEE',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            accountEmail: Text(
              userEmail,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
            currentAccountPicture: _buildAvatarWidget(avatar, userName, 28),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.home_rounded, color: Color(0xFF6366F1)),
                  title: Text('Dashboard', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 0);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today_rounded, color: Color(0xFF10B981)),
                  title: Text('Attendance Calendar', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 1);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.event_note_rounded, color: Color(0xFFF59E0B)),
                  title: Text('Apply Leave', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 2);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bar_chart_rounded, color: Color(0xFF3B82F6)),
                  title: Text('Reports & Analytics', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 3);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.payments_rounded, color: Color(0xFF06B6D4)),
                  title: Text('My Salary & Payroll', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/employee/salary');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.assignment_rounded, color: Color(0xFF8B5CF6)),
                  title: Text('My Tasks', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/employee/tasks');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.folder_special_rounded, color: Color(0xFFEC4899)),
                  title: Text('Projects', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/employee/projects');
                  },
                ),
                Divider(color: context.dividerCol),
                ListTile(
                  leading: const Icon(Icons.person_rounded, color: Color(0xFF64748B)),
                  title: Text('Account Settings', style: TextStyle(color: context.txtPrimary)),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/settings');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_rounded, color: Color(0xFF64748B)),
                  title: Text('Settings', style: TextStyle(color: context.txtPrimary)),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/settings');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                  title: const Text('Logout', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                  onTap: () async {
                    final router = GoRouter.of(context);
                    Navigator.pop(context);
                    await ref.read(authProvider.notifier).logout();
                    router.go('/welcome');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
    return _AttendanceCalendarTab();
  }

  Widget _buildLeaveTab() {
    return _LeaveTab();
  }

  Widget _buildReportsTab() {
    return const _ReportsTab();
  }

  Widget _buildSalaryTab() {
    return const _SalaryTab();
  }

  // --- Bottom Navigation Bar with 5 tabs ---
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: context.bottomNavBg,
        border: Border(
          top: BorderSide(
            color: context.borderCol.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4F46E5),
        unselectedItemColor: context.txtMuted,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today_rounded),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note_outlined),
            activeIcon: Icon(Icons.event_note_rounded),
            label: 'Leaves',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart_rounded),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payments_outlined),
            activeIcon: Icon(Icons.payments_rounded),
            label: 'Salary',
          ),
        ],
      ),
    );
  }
}

// Sparkline CustomPainter for stat card trend curve
class _SparklinePainter extends CustomPainter {
  final Color color;
  final List<double> points;

  _SparklinePainter({required this.color, required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final stepX = size.width / (points.length - 1);

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height - (points[i] * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevY = size.height - (points[i - 1] * size.height);
        final controlX1 = prevX + (stepX / 2);
        final controlY1 = prevY;
        final controlX2 = prevX + (stepX / 2);
        final controlY2 = y;
        path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Optional translucent fill below curve
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.25),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.points != points;
  }
}

// Reports Tab Widget
class _ReportsTab extends ConsumerWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendance = ref.watch(attendanceProvider);
    final stats = attendance.stats;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance & Work Reports',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.txtPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Monthly performance and attendance summary',
            style: TextStyle(
              fontSize: 13,
              color: context.txtMuted,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderCol),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics_rounded, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 10),
                    Text(
                      'Monthly Attendance Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.txtPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _reportRow(context, 'Present Days', stats?['presentDays']?.toString() ?? '0', const Color(0xFF10B981)),
                const SizedBox(height: 10),
                _reportRow(context, 'Absent Days', stats?['absentDays']?.toString() ?? '0', const Color(0xFFEF4444)),
                const SizedBox(height: 10),
                _reportRow(context, 'Late Days', stats?['lateDays']?.toString() ?? '0', const Color(0xFFF59E0B)),
                const SizedBox(height: 10),
                _reportRow(context, 'Approved Leaves', attendance.myLeaves.length.toString(), const Color(0xFF3B82F6)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportRow(BuildContext context, String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: context.txtSecondary, fontSize: 14)),
          ],
        ),
        Text(
          value,
          style: TextStyle(color: context.txtPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

Widget _buildAvatarWidget(dynamic avatarOrUser, String fallbackText, double radius) {
  String? cleanAvatar = extractAvatarUrl(avatarOrUser);
  if (cleanAvatar != null &&
      cleanAvatar.isNotEmpty &&
      cleanAvatar != 'null' &&
      cleanAvatar != 'undefined') {
    // 1. Base64 Data URI or Raw Base64 String
    if (cleanAvatar.startsWith('data:image/') ||
        cleanAvatar.startsWith('data:application/') ||
        (!cleanAvatar.startsWith('http://') &&
         !cleanAvatar.startsWith('https://') &&
         !cleanAvatar.startsWith('file://') &&
         !cleanAvatar.startsWith('/') &&
         !cleanAvatar.startsWith('uploads') &&
         cleanAvatar.length > 80)) {
      try {
        String base64Str = cleanAvatar.contains(',') ? cleanAvatar.split(',').last : cleanAvatar;
        base64Str = base64Str.replaceAll(RegExp(r'\s+'), '');
        while (base64Str.length % 4 != 0) {
          base64Str += '=';
        }
        final bytes = base64Decode(base64Str);
        if (bytes.isNotEmpty) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFFE0E7FF),
            backgroundImage: MemoryImage(bytes),
          );
        }
      } catch (_) {}
    }

    // 2. Local File Path
    if (cleanAvatar.startsWith('file://') || cleanAvatar.contains(':\\') || cleanAvatar.startsWith('/data/') || cleanAvatar.startsWith('/storage/')) {
      try {
        final filePath = cleanAvatar.replaceFirst('file://', '');
        final file = File(filePath);
        if (file.existsSync()) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFFE0E7FF),
            backgroundImage: FileImage(file),
          );
        }
      } catch (_) {}
    }

    // 3. Direct HTTP/HTTPS Network URL
    if (cleanAvatar.contains('localhost') ||
        cleanAvatar.contains('127.0.0.1') ||
        cleanAvatar.contains('10.0.2.2')) {
      final apiBase = ApiConstants.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
      cleanAvatar = cleanAvatar.replaceAll(
        RegExp(r'https?://(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?'),
        apiBase,
      );
    }

    if (!cleanAvatar.startsWith('http://') &&
        !cleanAvatar.startsWith('https://') &&
        (cleanAvatar.contains('cloudinary.com') ||
         cleanAvatar.contains('vercel.app') ||
         cleanAvatar.contains('onrender.com') ||
         cleanAvatar.contains('amazonaws.com') ||
         cleanAvatar.contains('googleapis.com') ||
         cleanAvatar.contains('supabase.co'))) {
      cleanAvatar = 'https://$cleanAvatar';
    }

    if (cleanAvatar.startsWith('http://') || cleanAvatar.startsWith('https://')) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: cleanAvatar,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (context, url) => CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFFE0E7FF),
            child: SizedBox(
              width: radius * 0.8,
              height: radius * 0.8,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFF4F46E5),
            child: Text(
              fallbackText.trim().isNotEmpty ? fallbackText.trim()[0].toUpperCase() : 'U',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.8,
              ),
            ),
          ),
        ),
      );
    }

    // 4. Relative Server Path (e.g. /uploads/..., uploads/...)
    if (cleanAvatar.startsWith('/') ||
        cleanAvatar.startsWith('uploads') ||
        cleanAvatar.startsWith('public') ||
        cleanAvatar.startsWith('storage') ||
        cleanAvatar.startsWith('images') ||
        cleanAvatar.startsWith('assets') ||
        cleanAvatar.startsWith('photos') ||
        cleanAvatar.startsWith('profiles') ||
        cleanAvatar.contains('.png') ||
        cleanAvatar.contains('.jpg') ||
        cleanAvatar.contains('.jpeg') ||
        cleanAvatar.contains('.webp') ||
        (!cleanAvatar.contains(' ') && cleanAvatar.contains('.'))) {
      final apiBase = ApiConstants.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
      final fullUrl = '$apiBase${cleanAvatar.startsWith('/') ? '' : '/'}$cleanAvatar';
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: fullUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (context, url) => CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFFE0E7FF),
            child: SizedBox(
              width: radius * 0.8,
              height: radius * 0.8,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFF4F46E5),
            child: Text(
              fallbackText.trim().isNotEmpty ? fallbackText.trim()[0].toUpperCase() : 'U',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.8,
              ),
            ),
          ),
        ),
      );
    }
  }

  // 5. Fallback Initial Letter
  return CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFF4F46E5),
    child: Text(
      fallbackText.trim().isNotEmpty ? fallbackText.trim()[0].toUpperCase() : 'U',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: radius * 0.8,
      ),
    ),
  );
}

// Salary Tab Widget
class _SalaryTab extends ConsumerWidget {
  const _SalaryTab();

  num _numVal(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    if (v is String) {
      final cleaned = v.replaceAll(RegExp(r'[^0-9.]'), '');
      return num.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  String _fmtCurrency(num amount) {
    final fmt = NumberFormat('#,##,###', 'en_IN');
    return '₹${fmt.format(amount)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salaryAsync = ref.watch(mySalaryProvider);
    final auth = ref.watch(authProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Salary & Payroll',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.txtPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pay slips, earnings and deduction details',
            style: TextStyle(
              fontSize: 13,
              color: context.txtMuted,
            ),
          ),
          const SizedBox(height: 20),
          salaryAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
              ),
            ),
            error: (e, _) => _buildSalaryHero(context, null, auth, ref),
            data: (salary) => _buildSalaryHero(context, salary, auth, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryHero(BuildContext context, Map<String, dynamic>? salary, AuthState auth, WidgetRef ref) {
    final user = auth.user;
    final userSalaryMap = user?['salary'] is Map ? Map<String, dynamic>.from(user!['salary']) : null;
    final activeData = salary ?? userSalaryMap;

    final basicSalary = _numVal(
      activeData?['basicSalary'] ??
      activeData?['basic'] ??
      activeData?['base'] ??
      activeData?['amount'] ??
      user?['basicSalary'] ??
      user?['salary']
    );
    final allowances = _numVal(
      activeData?['allowances'] ??
      activeData?['totalAllowances'] ??
      activeData?['bonus'] ??
      user?['allowances']
    );
    final deductions = _numVal(
      activeData?['deductions'] ??
      activeData?['totalDeductions'] ??
      activeData?['tax'] ??
      user?['deductions']
    );
    final netPay = _numVal(
      activeData?['netSalary'] ??
      activeData?['netPay'] ??
      activeData?['net'] ??
      (basicSalary > 0 ? (basicSalary + allowances - deductions) : 0)
    );

    if (basicSalary == 0 && netPay == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.payments_outlined, size: 48, color: Color(0xFF6366F1)),
              ),
              const SizedBox(height: 16),
              Text(
                'No Salary Record Available',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.txtPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your salary details have not been published by HR or Admin yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: context.txtMuted),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () => ref.refresh(mySalaryProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Check for Updates'),
              ),
            ],
          ),
        ),
      );
    }

    final month = activeData?['month']?.toString() ??
        activeData?['salaryMonth']?.toString() ??
        DateFormat('MMMM yyyy').format(DateTime.now());
    final status = activeData?['status']?.toString() ?? 'Processed';

    final empName = user?['name'] ?? 'Employee';
    final designation = user?['designation'] ?? user?['position'] ?? 'Software Engineer';
    final avatar = user?['avatar']?.toString() ??
        user?['profilePicture']?.toString() ??
        user?['image']?.toString();

    return Column(
      children: [
        // Salary Card Hero
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFF818CF8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildAvatarWidget(avatar, empName, 22),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        empName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        designation,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Net Salary - $month',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _fmtCurrency(netPay),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Salary Breakdown
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderCol),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Salary Breakdown',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.txtPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: () => ref.refresh(mySalaryProvider),
                    tooltip: 'Refresh Salary',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _itemRow(context, 'Base Salary', _fmtCurrency(basicSalary), const Color(0xFF10B981)),
              const SizedBox(height: 10),
              _itemRow(context, 'Allowances & Bonuses', '+ ${_fmtCurrency(allowances)}', const Color(0xFF3B82F6)),
              const SizedBox(height: 10),
              _itemRow(context, 'Deductions (Taxes & PF)', '- ${_fmtCurrency(deductions)}', const Color(0xFFEF4444)),
              const Divider(height: 24),
              _itemRow(context, 'Total Take Home', _fmtCurrency(netPay), const Color(0xFF4F46E5), isBold: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _itemRow(BuildContext context, String label, String value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? context.txtPrimary : context.txtSecondary,
            fontSize: isBold ? 15 : 13.5,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isBold ? const Color(0xFF4F46E5) : context.txtPrimary,
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// Attendance Calendar Tab Widget
class _AttendanceCalendarTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AttendanceCalendarTab> createState() =>
      _AttendanceCalendarTabState();
}

class _AttendanceCalendarTabState
    extends ConsumerState<_AttendanceCalendarTab> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadCalendar());
  }

  void _loadCalendar() {
    ref.read(attendanceProvider.notifier).loadCalendar(
          month: _currentMonth.month,
          year: _currentMonth.year,
        );
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month + delta);
    });
    _loadCalendar();
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'present':
        return AppColors.statusPresent;
      case 'absent':
        return AppColors.statusAbsent;
      case 'leave':
      case 'on leave':
        return AppColors.statusPending;
      case 'holiday':
        return AppColors.primaryLight;
      default:
        return AppColors.textMuted.withValues(alpha: 0.3);
    }
  }

  IconData _statusIcon(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'present':
        return Icons.check_circle_rounded;
      case 'absent':
        return Icons.cancel_rounded;
      case 'leave':
      case 'on leave':
        return Icons.beach_access_rounded;
      case 'holiday':
        return Icons.celebration_rounded;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  String _formatAttendanceDate(dynamic dateRaw) {
    try {
      final dt = DateTime.parse(dateRaw.toString()).toLocal();
      return DateFormat('EEE, d MMM').format(dt);
    } catch (_) {
      return dateRaw?.toString() ?? '';
    }
  }

  String _formatTime(dynamic time) {
    try {
      final dt = DateTime.parse(time.toString()).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return time?.toString() ?? '--:--';
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendance = ref.watch(attendanceProvider);
    final monthLabel = DateFormat('MMMM yyyy').format(_currentMonth);
    final records = attendance.calendarData;

    // Build summary counts from records
    int presentCount = 0, absentCount = 0, leaveCount = 0;
    for (final r in records) {
      final s = (r['status'] ?? '').toString().toLowerCase();
      if (s == 'present') presentCount++;
      if (s == 'absent') absentCount++;
      if (s == 'leave' || s == 'on leave') leaveCount++;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Navigator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left_rounded,
                    color: AppColors.primary, size: 28),
              ),
              Text(
                monthLabel,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.txtPrimary,
                ),
              ),
              IconButton(
                onPressed: _currentMonth.month == DateTime.now().month &&
                        _currentMonth.year == DateTime.now().year
                    ? null
                    : () => _changeMonth(1),
                icon: Icon(
                  Icons.chevron_right_rounded,
                  color: _currentMonth.month == DateTime.now().month &&
                          _currentMonth.year == DateTime.now().year
                      ? AppColors.textMuted.withValues(alpha: 0.3)
                      : AppColors.primary,
                  size: 28,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Summary Stats Row
          Row(
            children: [
              _summaryChip(
                  'Present', presentCount, AppColors.statusPresent),
              const SizedBox(width: 10),
              _summaryChip('Absent', absentCount, AppColors.statusAbsent),
              const SizedBox(width: 10),
              _summaryChip('Leaves', leaveCount, AppColors.statusPending),
            ],
          ),

          const SizedBox(height: 20),

          // Records List
          if (attendance.isCalendarLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (records.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(Icons.calendar_month_outlined,
                      size: 60,
                      color: AppColors.textMuted.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  const Text(
                    'No attendance records found',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Records will appear here once\nattendance is marked.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ...records.map((record) => _buildAttendanceRecordCard(record)),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceRecordCard(dynamic record) {
    final status = record['status']?.toString();
    final color = _statusColor(status);
    final icon = _statusIcon(status);
    final dateLabel = _formatAttendanceDate(
        record['date'] ?? record['attendanceDate'] ?? record['createdAt']);
    final checkIn = record['checkIn'] ?? record['checkInTime'];
    final checkOut = record['checkOut'] ?? record['checkOutTime'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLabel,
                  style: TextStyle(
                    color: context.txtPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                if (checkIn != null || checkOut != null)
                  Text(
                    '${checkIn != null ? "In: ${_formatTime(checkIn)}" : ""}${checkOut != null ? "  Out: ${_formatTime(checkOut)}" : ""}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  )
                else
                  Text(
                    status?.toUpperCase() ?? 'N/A',
                    style: TextStyle(
                        color: color, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              (status ?? 'N/A').toUpperCase(),
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// Leave Tab Widget
class _LeaveTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_LeaveTab> createState() => _LeaveTabState();
}

class _LeaveTabState extends ConsumerState<_LeaveTab> {
  String _leaveFilter = 'All';

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(attendanceProvider.notifier).loadMyLeaves());
  }

  @override
  Widget build(BuildContext context) {
    final attendance = ref.watch(attendanceProvider);
    final allMyLeaves = attendance.myLeaves;

    final approvedCount = allMyLeaves.where((l) => (l is Map && (l['status'] ?? '').toString().toLowerCase() == 'approved')).length;
    final pendingCount = allMyLeaves.where((l) => (l is Map && (l['status'] ?? '').toString().toLowerCase() == 'pending')).length;
    final rejectedCount = allMyLeaves.where((l) {
      if (l is! Map) return false;
      final st = (l['status'] ?? '').toString().toLowerCase();
      return st == 'rejected' || st == 'cancelled';
    }).length;

    final filtered = allMyLeaves.where((l) {
      if (l is! Map) return false;
      final st = (l['status'] ?? '').toString().toLowerCase();
      if (_leaveFilter == 'Approved') return st == 'approved';
      if (_leaveFilter == 'Pending') return st == 'pending';
      if (_leaveFilter == 'Rejected') return st == 'rejected' || st == 'cancelled';
      return true;
    }).toList();

    final filterOptions = [
      {'label': 'All', 'count': allMyLeaves.length, 'color': const Color(0xFF6366F1)},
      {'label': 'Approved', 'count': approvedCount, 'color': const Color(0xFF10B981)},
      {'label': 'Pending', 'count': pendingCount, 'color': const Color(0xFFF59E0B)},
      {'label': 'Rejected', 'count': rejectedCount, 'color': const Color(0xFFEF4444)},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Leave Status',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.txtPrimary),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showApplyLeaveSheet(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Apply'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filterOptions.map((opt) {
                final label = opt['label'] as String;
                final count = opt['count'] as int;
                final color = opt['color'] as Color;
                final isSel = _leaveFilter == label;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _leaveFilter = label),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? color : context.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel ? color : context.borderCol,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: isSel ? Colors.white : context.txtPrimary,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '($count)',
                            style: TextStyle(
                              color: isSel ? Colors.white.withValues(alpha: 0.9) : color,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          if (attendance.isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else if (filtered.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(Icons.beach_access,
                      size: 60, color: AppColors.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    _leaveFilter == 'Approved'
                        ? 'No approved leaves found'
                        : _leaveFilter == 'Pending'
                            ? 'No pending leaves found'
                            : 'No leaves found',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          else
            ...filtered.map((leave) => _buildLeaveCard(leave)),
        ],
      ),
    );
  }

  Widget _buildLeaveCard(dynamic leave) {
    final status = leave['status'] ?? 'Pending';
    final Color statusColor = status == 'Approved'
        ? AppColors.statusPresent
        : status == 'Rejected'
            ? AppColors.statusAbsent
            : AppColors.statusPending;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                leave['leaveType'] ?? 'Leave',
                style: TextStyle(
                    color: context.txtPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatDate(leave['startDate'])} → ${_formatDate(leave['endDate'])}',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (leave['reason'] != null && leave['reason'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                leave['reason'],
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(date.toString()));
    } catch (_) {
      return date?.toString() ?? 'N/A';
    }
  }

  void _showApplyLeaveSheet(BuildContext context) {
    final leaveTypeController = ValueNotifier<String>('Sick Leave');
    final reasonController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: context.borderCol),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Apply Leave',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: context.txtPrimary)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: leaveTypeController.value,
                dropdownColor: context.cardBg,
                style: TextStyle(color: context.txtPrimary),
                decoration: InputDecoration(
                  labelText: 'Leave Type',
                  filled: true,
                  fillColor: context.cardLightBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.borderCol),
                  ),
                ),
                items: [
                  'Sick Leave',
                  'Casual Leave',
                  'Paid Leave',
                  'Emergency Leave',
                  'Unpaid Leave'
                ]
                    .map((e) =>
                        DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) leaveTypeController.value = v;
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (d != null) setModalState(() => startDate = d);
                      },
                      child: _datePickerField(
                          'Start Date',
                          startDate != null
                              ? DateFormat('dd MMM').format(startDate!)
                              : null),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: startDate ?? DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (d != null) setModalState(() => endDate = d);
                      },
                      child: _datePickerField(
                          'End Date',
                          endDate != null
                              ? DateFormat('dd MMM').format(endDate!)
                              : null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: reasonController,
                maxLines: 2,
                style: TextStyle(color: context.txtPrimary),
                decoration: InputDecoration(
                  labelText: 'Reason (optional)',
                  filled: true,
                  fillColor: context.cardLightBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.borderCol),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (startDate == null || endDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Select dates')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final ok = await ref
                        .read(attendanceProvider.notifier)
                        .applyLeave(
                          leaveType: leaveTypeController.value,
                          startDate: startDate!.toIso8601String(),
                          endDate: endDate!.toIso8601String(),
                          reason: reasonController.text,
                        );
                    if (ok && mounted) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Leave applied successfully!'),
                            backgroundColor: AppColors.statusPresent),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Submit',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _datePickerField(String label, String? value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: context.cardLightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderCol),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today,
              color: context.txtMuted, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: context.txtMuted, fontSize: 11)),
              Text(
                value ?? 'Select',
                style: TextStyle(
                    color: context.txtPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Logout button
class CustomLogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const CustomLogoutButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.logout, color: AppColors.accentRed),
        label: const Text('Logout',
            style:
                TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: AppColors.accentRed),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

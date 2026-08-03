import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
        color: context.cardBg.withValues(alpha: 0.85),
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
            icon: Icon(Icons.menu_rounded, color: context.txtPrimary, size: 24),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const SizedBox(width: 4),
          Column(
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
              ),
              const SizedBox(height: 2),
              Text(
                today,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: context.txtMuted,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Theme Mode Toggle (Light / Dark)
          IconButton(
            icon: Icon(
              ref.watch(themeProvider) == ThemeMode.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: ref.watch(themeProvider) == ThemeMode.dark
                  ? const Color(0xFFFBBF24)
                  : const Color(0xFF6366F1),
              size: 22,
            ),
            tooltip: ref.watch(themeProvider) == ThemeMode.dark
                ? 'Switch to Light Mode'
                : 'Switch to Dark Mode',
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme();
            },
          ),
          // Notification Bell with Badge Count
          Consumer(
            builder: (ctx, cref, _) {
              final notifs = cref.watch(notificationsProvider);
              final count = notifs.when(
                data: (list) => list.where((n) {
                  if (n is! Map) return false;
                  final read = n['read'] ?? n['isRead'] ?? false;
                  return read == false;
                }).length,
                loading: () => 0,
                error: (e, _) => 0,
              );
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.notifications_none_rounded,
                      color: context.txtPrimary,
                      size: 24,
                    ),
                    onPressed: () => context.go('/employee/notifications'),
                  ),
                  if (count > 0)
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
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          count > 99 ? '99+' : count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
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
          // Logout Button
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: Color(0xFFEF4444),
              size: 22,
            ),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (mounted) context.go('/login');
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
    if (_selectedIndex == 3) return _buildProfileTab();
    return _buildDashboardTab();
  }

  // --- Main Dashboard View (Admin Design Style) ---
  Widget _buildDashboardTab() {
    final attendance = ref.watch(attendanceProvider);
    final auth = ref.watch(authProvider);

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
    final totalDays = stats?['totalDays']?.toString() ??
        stats?['total']?.toString() ??
        (attendance.calendarData.isNotEmpty ? attendance.calendarData.length.toString() : '0');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Welcome Banner Hero Card (Admin style)
          _buildWelcomeBanner(authName: auth.user?['name'] ?? 'Employee'),

          const SizedBox(height: 24),

          // 2. Today's Attendance Check In / Check Out Card
          _buildAttendanceCard(attendance),

          const SizedBox(height: 24),

          // 3. Overview Section Header & Stat Cards Grid (Admin style)
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
              IconButton(
                icon: Icon(Icons.refresh_rounded, size: 18, color: context.txtMuted),
                onPressed: () {
                  ref.read(attendanceProvider.notifier).loadTodayAttendance();
                  ref.read(attendanceProvider.notifier).loadStats();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildOverviewCard(
                title: 'Present Days',
                value: presentDays,
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF10B981),
                bgColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              _buildOverviewCard(
                title: 'Absent Days',
                value: absentDays,
                icon: Icons.cancel_rounded,
                color: const Color(0xFFEF4444),
                bgColor: const Color(0xFFEF4444).withValues(alpha: 0.12),
              ),
              _buildOverviewCard(
                title: 'On Leave',
                value: leaveDays,
                icon: Icons.calendar_month_rounded,
                color: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                onTap: () => setState(() => _selectedIndex = 2),
              ),
              _buildOverviewCard(
                title: 'Total Days',
                value: totalDays,
                icon: Icons.access_time_filled_rounded,
                color: const Color(0xFF06B6D4),
                bgColor: const Color(0xFF06B6D4).withValues(alpha: 0.12),
              ),
            ],
          ).animate().slideY(
                begin: 0.15,
                end: 0,
                duration: const Duration(milliseconds: 350),
              ),

          const SizedBox(height: 24),

          // 4. Quick Actions Section (Admin style icon buttons)
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.txtPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuickActionButton(
                icon: Icons.access_time_filled_rounded,
                label: 'Attendance',
                color: const Color(0xFF10B981),
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              _buildQuickActionButton(
                icon: Icons.event_available_rounded,
                label: 'Apply Leave',
                color: const Color(0xFFF59E0B),
                onTap: () => setState(() => _selectedIndex = 2),
              ),
              _buildQuickActionButton(
                icon: Icons.payments_rounded,
                label: 'My Salary',
                color: const Color(0xFF06B6D4),
                onTap: () => context.push('/employee/salary'),
              ),
              _buildQuickActionButton(
                icon: Icons.assignment_rounded,
                label: 'My Tasks',
                color: const Color(0xFF6366F1),
                onTap: () => context.push('/employee/tasks'),
              ),
            ],
          ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
        ],
      ),
    );
  }

  // --- Hero Welcome Banner ---
  Widget _buildWelcomeBanner({required String authName}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2563EB),
            Color(0xFF3B82F6),
            Color(0xFF1D4ED8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back,',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    authName.split(' ').first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('👋', style: TextStyle(fontSize: 22)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "Here's your attendance & work overview.",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 0,
            top: 0,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.badge_rounded, color: Colors.white, size: 30),
                  SizedBox(height: 4),
                  Icon(Icons.show_chart_rounded, color: Colors.white70, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().scale(duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  // --- Overview Stat Card Component (Admin design style) ---
  Widget _buildOverviewCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.borderCol,
            width: 1,
          ),
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
                    color: bgColor,
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
            const SizedBox(height: 8),
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
                  title,
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
      ),
    );
  }

  // --- Quick Action Icon Button ---
  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: context.txtSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // --- Employee Drawer ---
  Widget _buildEmployeeDrawer(BuildContext context, WidgetRef ref, AuthState auth) {
    final userName = auth.user?['name'] ?? 'Employee User';
    final userEmail = auth.user?['email'] ?? 'employee@ams.com';

    return Drawer(
      backgroundColor: context.cardBg,
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
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white24,
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'E',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.dashboard_rounded, color: Color(0xFF6366F1)),
                  title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 0);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.access_time_filled_rounded, color: Color(0xFF10B981)),
                  title: const Text('Attendance Calendar', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 1);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.event_available_rounded, color: Color(0xFFF59E0B)),
                  title: const Text('Apply Leave', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 2);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.payments_rounded, color: Color(0xFF06B6D4)),
                  title: const Text('My Salary & Payroll', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/employee/salary');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.assignment_rounded, color: Color(0xFF8B5CF6)),
                  title: const Text('My Tasks', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/employee/tasks');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active_rounded, color: Color(0xFFF59E0B)),
                  title: const Text('Notifications Center', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/employee/notifications');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person_rounded, color: Color(0xFF64748B)),
                  title: const Text('My Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 3);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_rounded, color: Color(0xFF64748B)),
                  title: const Text('Settings & Biometrics'),
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
                    router.go('/login');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceState attendance) {
    final isCheckedIn = attendance.isCheckedIn;
    final isCheckedOut = attendance.isCheckedOut;
    final todayData = attendance.todayAttendance;
    final checkInTime = todayData?['checkIn'] != null
        ? _formatTime(todayData!['checkIn'])
        : '--:--';
    final checkOutTime = todayData?['checkOut'] != null
        ? _formatTime(todayData!['checkOut'])
        : '--:--';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.fingerprint, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              const Text(
                "Today's Attendance",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isCheckedOut
                      ? 'Done'
                      : isCheckedIn
                          ? 'Checked In'
                          : 'Not Marked',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Time display
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Check In',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      checkInTime,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Check Out',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      checkOutTime,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Action button
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
                    : const Icon(Icons.login, color: Colors.white),
                label: Text(
                  attendance.isLoading ? 'Marking...' : 'Mark Check In',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
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
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  'Mark Check Out',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            )
          else
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Attendance Completed for Today',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ],
            ),
        ],
      ),
    ).animate().scale(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
  }


  Widget _buildAttendanceTab() {
    return _AttendanceCalendarTab();
  }

  Widget _buildLeaveTab() {
    return _LeaveTab();
  }

  Widget _buildProfileTab() {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Center(
              child: Text(
                (user?['name'] ?? 'U')[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user?['name'] ?? 'User',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user?['email'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Text(
              (user?['role'] ?? 'Employee').toString().toUpperCase(),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 30),
          _buildProfileItem(Icons.work_outline, 'Department',
              user?['department'] ?? 'N/A'),
          _buildProfileItem(
              Icons.badge_outlined, 'Position', user?['position'] ?? 'N/A'),
          _buildProfileItem(
              Icons.phone_outlined, 'Phone', user?['phone'] ?? 'N/A'),
          const SizedBox(height: 24),
          CustomLogoutButton(onTap: () async {
            await ref.read(authProvider.notifier).logout();
            if (mounted) context.go('/login');
          }),
        ],
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }



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
        selectedItemColor: AppColors.primary,
        unselectedItemColor: context.txtMuted,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Attendance'),
          BottomNavigationBarItem(
              icon: Icon(Icons.beach_access_outlined),
              activeIcon: Icon(Icons.beach_access),
              label: 'Leaves'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }

  String _formatTime(dynamic time) {
    try {
      final dt = DateTime.parse(time.toString()).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return time.toString();
    }
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
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
        color: AppColors.bgCard,
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
                  style: const TextStyle(
                    color: AppColors.textPrimary,
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
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(attendanceProvider.notifier).loadMyLeaves());
  }

  @override
  Widget build(BuildContext context) {
    final attendance = ref.watch(attendanceProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'My Leaves',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
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
          const SizedBox(height: 16),
          if (attendance.isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else if (attendance.myLeaves.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(Icons.beach_access,
                      size: 60, color: AppColors.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('No leaves found',
                      style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            )
          else
            ...attendance.myLeaves.map((leave) => _buildLeaveCard(leave)),
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
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                leave['leaveType'] ?? 'Leave',
                style: const TextStyle(
                    color: AppColors.textPrimary,
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
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Apply Leave',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: leaveTypeController.value,
                dropdownColor: AppColors.bgCardLight,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Leave Type',
                  filled: true,
                  fillColor: AppColors.bgCardLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderColor),
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
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Reason (optional)',
                  filled: true,
                  fillColor: AppColors.bgCardLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderColor),
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
        color: AppColors.bgCardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today,
              color: AppColors.textMuted, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
              Text(
                value ?? 'Select',
                style: const TextStyle(
                    color: AppColors.textPrimary,
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

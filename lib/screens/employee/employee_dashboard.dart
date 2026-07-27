import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../widgets/dashboard/stat_card.dart';

class EmployeeDashboard extends ConsumerStatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  ConsumerState<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends ConsumerState<EmployeeDashboard> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
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
    final today = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
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

  Widget _buildHeader(String name, String today, AuthState auth) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.15),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${name.split(' ').first} 👋',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                today,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Profile Avatar
          GestureDetector(
            onTap: () => context.go('/employee/profile'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  ((auth.user?['name'] != null &&
                          (auth.user!['name'].toString().trim().isNotEmpty))
                      ? auth.user!['name'].toString().trim()[0]
                      : 'U')
                      .toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 400));
  }

  Widget _buildBody() {
    if (_selectedIndex == 0) return _buildDashboardTab();
    if (_selectedIndex == 1) return _buildAttendanceTab();
    if (_selectedIndex == 2) return _buildLeaveTab();
    if (_selectedIndex == 3) return _buildProfileTab();
    return _buildDashboardTab();
  }

  Widget _buildDashboardTab() {
    final attendance = ref.watch(attendanceProvider);
    final auth = ref.watch(authProvider);
    
    // Parse settings and quickActions from profile data
    final settings = auth.user?['settings'] as Map<String, dynamic>?;
    final quickActions = settings?['quickActions'] as Map<String, dynamic>?;

    final showTasks = quickActions?['myTasks'] ?? true;
    final showLeave = quickActions?['applyLeave'] ?? true;
    final showSalary = quickActions?['mySalary'] ?? true;
    final showShifts = quickActions?['myShifts'] ?? true;

    final List<Widget> actions = [];
    if (showTasks) {
      actions.add(_buildQuickAction(
        icon: Icons.task_alt,
        label: 'My Tasks',
        color: AppColors.accent,
        onTap: () => context.go('/employee/tasks'),
      ));
    }
    if (showLeave) {
      actions.add(_buildQuickAction(
        icon: Icons.beach_access,
        label: 'Apply Leave',
        color: AppColors.accentOrange,
        onTap: () => setState(() => _selectedIndex = 2),
      ));
    }
    if (showSalary) {
      actions.add(_buildQuickAction(
        icon: Icons.payment,
        label: 'My Salary',
        color: AppColors.accentGreen,
        onTap: () => context.go('/employee/salary'),
      ));
    }
    if (showShifts) {
      actions.add(_buildQuickAction(
        icon: Icons.schedule,
        label: 'My Shifts',
        color: AppColors.primaryLight,
        onTap: () => context.go('/employee/shifts'),
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Today's Attendance Card
          _buildAttendanceCard(attendance),

          const SizedBox(height: 24),

          if (actions.isNotEmpty) ...[
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: actions,
            ).animate().slideY(
                  begin: 0.3,
                  end: 0,
                  delay: const Duration(milliseconds: 200),
                  duration: const Duration(milliseconds: 400),
                ),
            const SizedBox(height: 24),
          ],

          // Stats
          const Text(
            'My Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 16),

          _buildStatsRow(attendance),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceState attendance) {
    final now = DateTime.now();
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
            color: AppColors.primary.withOpacity(0.35),
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
                  color: Colors.white.withOpacity(0.2),
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
                color: Colors.white.withOpacity(0.3),
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
                  backgroundColor: Colors.white.withOpacity(0.25),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.white.withOpacity(0.5)),
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
                        }
                      },
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  'Mark Check Out',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.25),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.white.withOpacity(0.5)),
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

  Widget _buildStatsRow(AttendanceState attendance) {
    final stats = attendance.stats;
    return Row(
      children: [
        Expanded(
          child: StatCard(
            title: 'Present',
            value: stats?['presentDays']?.toString() ?? '--',
            icon: Icons.check_circle_outline,
            gradient: AppColors.greenGradient,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            title: 'Absent',
            value: stats?['absentDays']?.toString() ?? '--',
            icon: Icons.cancel_outlined,
            gradient: AppColors.redGradient,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            title: 'Leaves',
            value: stats?['leaveDays']?.toString() ?? '--',
            icon: Icons.beach_access_outlined,
            gradient: AppColors.orangeGradient,
          ),
        ),
      ],
    ).animate().slideY(
          begin: 0.3,
          end: 0,
          delay: const Duration(milliseconds: 400),
          duration: const Duration(milliseconds: 400),
        );
  }

  Widget _buildAttendanceTab() {
    return const Center(
      child: Text(
        'Attendance Calendar',
        style: TextStyle(color: AppColors.textPrimary),
      ),
    );
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
                  color: AppColors.primary.withOpacity(0.35),
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
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
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

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BottomNavigationBar _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
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
                      size: 60, color: AppColors.textMuted.withOpacity(0.5)),
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
                  color: statusColor.withOpacity(0.15),
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
                value: leaveTypeController.value,
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

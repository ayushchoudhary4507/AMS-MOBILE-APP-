import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/employee_provider.dart';
import '../../widgets/dashboard/stat_card.dart';
import '../employee/employee_dashboard.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(attendanceProvider.notifier).loadStats();
      ref.read(employeeProvider.notifier).loadEmployees();
      ref.read(attendanceProvider.notifier).loadAllLeaves(status: 'Pending');
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(auth.user?['name'] ?? 'Admin', today),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader(String name, String today) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderColor.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Admin Panel',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                today,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              ref.read(attendanceProvider.notifier).loadStats();
              ref.read(employeeProvider.notifier).loadEmployees();
            },
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.4),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_rounded, color: AppColors.primaryLight, size: 14),
                SizedBox(width: 6),
                Text(
                  'ADMIN',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 400));
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildEmployeesTab();
      case 2:
        return _buildLeaveApprovalTab();
      case 3:
        return _buildMoreTab();
      default:
        return _buildDashboardTab();
    }
  }

  Widget _buildDashboardTab() {
    final attendance = ref.watch(attendanceProvider);
    final employees = ref.watch(employeeProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Overview Header
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Total Employees',
                  value: employees.employees.length.toString(),
                  icon: Icons.people_outline_rounded,
                  gradient: AppColors.primaryGradient,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Present Today',
                  value: attendance.stats?['presentCount']?.toString() ?? '--',
                  icon: Icons.check_circle_outline_rounded,
                  gradient: AppColors.greenGradient,
                ),
              ),
            ],
          ).animate().slideY(
                begin: 0.2,
                end: 0,
                duration: const Duration(milliseconds: 350),
              ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Absent Today',
                  value: attendance.stats?['absentCount']?.toString() ?? '--',
                  icon: Icons.cancel_outlined,
                  gradient: AppColors.redGradient,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'On Leave',
                  value: attendance.stats?['leaveCount']?.toString() ?? '--',
                  icon: Icons.beach_access_outlined,
                  gradient: AppColors.orangeGradient,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
              ),
            ],
          ).animate().slideY(
                begin: 0.2,
                end: 0,
                delay: const Duration(milliseconds: 80),
                duration: const Duration(milliseconds: 350),
              ),

          const SizedBox(height: 28),

          // Pending Leaves
          _buildPendingLeavesSection(),

          const SizedBox(height: 28),

          // Quick Admin Actions Header
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.35,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildActionTile(
                icon: Icons.people_alt_rounded,
                label: 'Employees',
                color: AppColors.primary,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              _buildActionTile(
                icon: Icons.insights_rounded,
                label: 'Analytics',
                color: AppColors.accent,
                onTap: () => context.go('/admin/analytics'),
              ),
              _buildActionTile(
                icon: Icons.folder_copy_rounded,
                label: 'Projects',
                color: AppColors.accentOrange,
                onTap: () => context.go('/admin/projects'),
              ),
              _buildActionTile(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Salary',
                color: AppColors.accentGreen,
                onTap: () => context.go('/admin/salary'),
              ),
            ],
          ).animate().fadeIn(delay: const Duration(milliseconds: 250)),
        ],
      ),
    );
  }

  Widget _buildPendingLeavesSection() {
    final attendance = ref.watch(attendanceProvider);
    final pendingLeaves = attendance.allLeaves
        .where((l) => (l['status'] ?? '').toString() == 'Pending')
        .toList();

    if (pendingLeaves.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Pending Leaves',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                pendingLeaves.length.toString(),
                style: const TextStyle(
                  color: AppColors.accentOrange,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...pendingLeaves.take(3).map((leave) => _buildLeaveApprovalCard(leave)),
      ],
    );
  }

  Widget _buildLeaveApprovalCard(dynamic leave) {
    final employeeName =
        leave['employee']?['name'] ?? leave['employeeName'] ?? 'Unknown';
    final leaveType = leave['leaveType'] ?? 'Leave';
    final leaveId = leave['_id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (employeeName.toString().trim().isNotEmpty
                            ? employeeName.toString().trim()[0]
                            : 'E')
                        .toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employeeName,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                    Text(
                      leaveType,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _approveLeave(leaveId, 'Rejected'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentRed,
                    side: const BorderSide(color: AppColors.accentRed),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Reject',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _approveLeave(leaveId, 'Approved'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusPresent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Approve',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approveLeave(String leaveId, String status) async {
    final ok = await ref
        .read(attendanceProvider.notifier)
        .approveRejectLeave(leaveId, status, null);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Leave $status successfully'),
          backgroundColor: status == 'Approved'
              ? AppColors.statusPresent
              : AppColors.accentRed,
        ),
      );
    }
  }

  Widget _buildEmployeesTab() {
    final state = ref.watch(employeeProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Text(
                'Employees',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${state.employees.length} total',
                  style: const TextStyle(
                      color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : state.employees.isEmpty
                  ? const Center(
                      child: Text('No employees found',
                          style: TextStyle(color: AppColors.textMuted)))
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(employeeProvider.notifier).loadEmployees(),
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        itemCount: state.employees.length,
                        itemBuilder: (ctx, i) =>
                            _buildEmployeeCard(state.employees[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmployeeCard(dynamic emp) {
    final name = emp['name'] ?? 'Unknown';
    final email = emp['email'] ?? '';
    final dept = emp['department'] ?? 'N/A';
    final role = emp['role'] ?? 'employee';
    final status = emp['status'] ?? 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (name.toString().trim().isNotEmpty
                        ? name.toString().trim()[0]
                        : 'E')
                    .toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  '$email · $dept',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (status == 'active'
                          ? AppColors.statusPresent
                          : AppColors.accentRed)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                      color: status == 'active'
                          ? AppColors.statusPresent
                          : AppColors.accentRed,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                role,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveApprovalTab() {
    final attendance = ref.watch(attendanceProvider);
    final leaves = attendance.allLeaves;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Text(
                'Leave Requests',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                color: AppColors.bgCardLight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.bgCardLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: const Row(
                    children: [
                      Text('Filter',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      Icon(Icons.keyboard_arrow_down,
                          color: AppColors.textMuted, size: 16),
                    ],
                  ),
                ),
                onSelected: (v) => ref
                    .read(attendanceProvider.notifier)
                    .loadAllLeaves(status: v == 'All' ? null : v),
                itemBuilder: (ctx) => ['All', 'Pending', 'Approved', 'Rejected']
                    .map((s) => PopupMenuItem(
                          value: s,
                          child: Text(s,
                              style: const TextStyle(
                                  color: AppColors.textPrimary)),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        Expanded(
          child: attendance.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : leaves.isEmpty
                  ? const Center(
                      child: Text('No leave requests',
                          style: TextStyle(color: AppColors.textMuted)))
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () =>
                          ref.read(attendanceProvider.notifier).loadAllLeaves(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: leaves.length,
                        itemBuilder: (ctx, i) =>
                            _buildLeaveApprovalCard(leaves[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildMoreTab() {
    final auth = ref.watch(authProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildMoreItem(Icons.holiday_village_outlined, 'Holidays',
              () => context.go('/admin/holidays')),
          _buildMoreItem(Icons.analytics_outlined, 'Analytics',
              () => context.go('/admin/analytics')),
          _buildMoreItem(Icons.folder_outlined, 'Projects',
              () => context.go('/admin/projects')),
          _buildMoreItem(
              Icons.payment_outlined, 'Salary', () => context.go('/admin/salary')),
          _buildMoreItem(Icons.notifications_outlined, 'Notifications',
              () => context.go('/admin/notifications')),
          const SizedBox(height: 12),
          const Divider(color: AppColors.dividerColor),
          const SizedBox(height: 12),
          CustomLogoutButton(onTap: () async {
            await ref.read(authProvider.notifier).logout();
            if (mounted) context.go('/login');
          }),
        ],
      ),
    );
  }

  Widget _buildMoreItem(IconData icon, String label, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        tileColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderColor),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(label,
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right,
            color: AppColors.textMuted, size: 20),
        onTap: onTap,
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withOpacity(0.22),
              width: 1.2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                AppColors.bgCard,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withOpacity(0.35),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border(
          top: BorderSide(
            color: AppColors.borderColor.withOpacity(0.6),
            width: 1,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: AppColors.textMuted,
        onTap: (i) {
          setState(() => _selectedIndex = i);
          if (i == 2) {
            ref.read(attendanceProvider.notifier).loadAllLeaves();
          }
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_outline_rounded),
              activeIcon: Icon(Icons.people_rounded),
              label: 'Employees'),
          BottomNavigationBarItem(
              icon: Icon(Icons.event_note_outlined),
              activeIcon: Icon(Icons.event_note_rounded),
              label: 'Leaves'),
          BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: 'More'),
        ],
      ),
    );
  }
}

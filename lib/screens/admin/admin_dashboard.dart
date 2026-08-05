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
import '../employee/employee_dashboard.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    StorageService.saveLastRoute('/admin/dashboard');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(attendanceProvider.notifier).loadStats();
      ref.read(attendanceProvider.notifier).loadTodayAllAttendance();
      ref.read(employeeProvider.notifier).loadEmployees();
      ref.read(attendanceProvider.notifier).loadAllLeaves(status: 'Pending');
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildAdminDrawer(context, ref, auth),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () => _showAddEmployeeModal(context),
              icon: const Icon(Icons.person_add_rounded, color: Colors.white),
              label: const Text(
                'Add Employee',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFF6366F1),
            )
          : null,
      body: Container(
        decoration: BoxDecoration(gradient: context.mainBgGradient),
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

  // --- Top Header Bar ---
  Widget _buildHeader(String name, String today) {
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
                'Admin Panel',
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
          // Notification Bell — real unread count from backend
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
                    onPressed: () => context.go('/admin/notifications'),
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
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildEmployeesTab();
      case 2:
        return _buildLeaveApprovalTab();
      case 3:
        return _buildReportsTab();
      case 4:
        return _buildMoreTab();
      default:
        return _buildDashboardTab();
    }
  }

  // --- Main Dashboard View ---
  Widget _buildDashboardTab() {
    final attendance = ref.watch(attendanceProvider);
    final employees = ref.watch(employeeProvider);

    final stats = attendance.stats;

    final totalEmpCount = employees.employees.isNotEmpty
        ? employees.employees.length
        : int.tryParse(stats?['totalEmployees']?.toString() ??
                stats?['total']?.toString() ??
                stats?['totalCount']?.toString() ??
                '') ??
            0;

    final todayPresentCount = attendance.todayAllAttendance.where((item) {
      if (item is! Map) return false;
      final st = (item['status'] ?? '').toString().toLowerCase();
      final hasCheckIn = item['checkIn'] != null ||
          item['check_in'] != null ||
          item['checkInTime'] != null ||
          item['check_in_time'] != null;
      return st == 'present' ||
          st == 'checked_in' ||
          st == 'late' ||
          st == 'half_day' ||
          st == 'on_time' ||
          hasCheckIn;
    }).length;

    final statsPresent = int.tryParse(stats?['presentCount']?.toString() ??
        stats?['present']?.toString() ??
        stats?['presentToday']?.toString() ??
        stats?['totalPresent']?.toString() ??
        stats?['todayPresent']?.toString() ??
        '');

    final presentCountVal = todayPresentCount > 0
        ? todayPresentCount
        : (statsPresent ?? (attendance.isCheckedIn ? 1 : 0));

    final leaveCountVal = int.tryParse(stats?['leaveCount']?.toString() ??
            stats?['onLeave']?.toString() ??
            stats?['leave']?.toString() ??
            stats?['approvedLeaves']?.toString() ??
            '') ??
        attendance.allLeaves.length;

    final absentCountVal = int.tryParse(stats?['absentCount']?.toString() ??
            stats?['absent']?.toString() ??
            stats?['absentToday']?.toString() ??
            '') ??
        ((totalEmpCount - presentCountVal - leaveCountVal) < 0
            ? 0
            : (totalEmpCount - presentCountVal - leaveCountVal));

    final totalEmp = totalEmpCount.toString();
    final presentCount = presentCountVal.toString();
    final leaveCount = leaveCountVal.toString();
    final absentCount = absentCountVal.toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Welcome Banner Hero Card
          _buildWelcomeBanner(authName: ref.watch(authProvider).user?['name'] ?? 'Admin'),
          const SizedBox(height: 24),

          // 2. Overview Section Header & Stat Cards
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
                  ref.read(attendanceProvider.notifier).loadStats();
                  ref.read(employeeProvider.notifier).loadEmployees();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4 Stat Cards Row / Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildOverviewCard(
                title: 'Total Employees',
                value: totalEmp,
                icon: Icons.groups_rounded,
                color: const Color(0xFF6366F1),
                bgColor: const Color(0xFF6366F1).withValues(alpha: 0.12),
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              _buildOverviewCard(
                title: 'Present Today',
                value: presentCount,
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF10B981),
                bgColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                onTap: () => _showAttendanceModal(context, ref,
                    title: 'Present Employees Today', statusType: 'present'),
              ),
              _buildOverviewCard(
                title: 'On Leave',
                value: leaveCount,
                icon: Icons.calendar_month_rounded,
                color: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                onTap: () => _showAttendanceModal(context, ref,
                    title: 'Employees On Leave', statusType: 'leave'),
              ),
              _buildOverviewCard(
                title: 'Absent Today',
                value: absentCount,
                icon: Icons.cancel_rounded,
                color: const Color(0xFFEF4444),
                bgColor: const Color(0xFFEF4444).withValues(alpha: 0.12),
                onTap: () => _showAttendanceModal(context, ref,
                    title: 'Absent Employees Today', statusType: 'absent'),
              ),
            ],
          ).animate().slideY(
                begin: 0.15,
                end: 0,
                duration: const Duration(milliseconds: 350),
              ),

          const SizedBox(height: 24),

          // 3. Pending Leaves Section
          _buildPendingLeavesSection(),

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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuickActionButton(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Add Employee',
                color: const Color(0xFF6366F1),
                onTap: () => _showAddEmployeeModal(context),
              ),
              _buildQuickActionButton(
                icon: Icons.access_time_filled_rounded,
                label: 'Attendance',
                color: const Color(0xFF10B981),
                onTap: () => _showAdminMarkAttendanceModal(context),
              ),
              _buildQuickActionButton(
                icon: Icons.event_available_rounded,
                label: 'Leaves',
                color: const Color(0xFFF59E0B),
                onTap: () => setState(() => _selectedIndex = 2),
              ),
              _buildQuickActionButton(
                icon: Icons.insert_chart_rounded,
                label: 'Reports',
                color: const Color(0xFF06B6D4),
                onTap: () => setState(() => _selectedIndex = 3),
              ),
            ],
          ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
        ],
      ),
    );
  }

  void _showAttendanceModal(BuildContext context, WidgetRef ref,
      {required String title, required String statusType}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final attendance = ref.watch(attendanceProvider);
          final employees = ref.watch(employeeProvider);

          final todayList = attendance.todayAllAttendance;
          final allEmployees = employees.employees;

          List<Map<String, dynamic>> displayList = [];

          if (statusType == 'present') {
            for (var item in todayList) {
              if (item is! Map) continue;
              final st = (item['status'] ?? '').toString().toLowerCase();
              final hasCheckIn = item['checkIn'] != null ||
                  item['check_in'] != null ||
                  item['checkInTime'] != null ||
                  item['check_in_time'] != null;

              if (st == 'present' ||
                  st == 'checked_in' ||
                  st == 'late' ||
                  st == 'half_day' ||
                  st == 'on_time' ||
                  hasCheckIn) {
                String empName = 'Employee';
                String empEmail = '';
                if (item['employee'] is Map) {
                  empName = item['employee']['name'] ?? 'Employee';
                  empEmail = item['employee']['email'] ?? '';
                } else if (item['user'] is Map) {
                  empName = item['user']['name'] ?? 'Employee';
                  empEmail = item['user']['email'] ?? '';
                } else if (item['name'] != null) {
                  empName = item['name']?.toString() ?? 'Employee';
                  empEmail = item['email']?.toString() ?? '';
                }
                displayList.add({
                  'name': empName,
                  'email': empEmail,
                  'checkIn': item['checkIn'] ?? item['check_in'] ?? item['checkInTime'] ?? item['check_in_time'],
                  'status': 'Present',
                });
              }
            }

            if (attendance.isCheckedIn) {
              final myUser = ref.read(authProvider).user;
              final myName = myUser?['name'] ?? 'Employee';
              final myEmail = myUser?['email'] ?? '';

              final alreadyInList = displayList.any((e) =>
                  (e['name'] ?? '').toString().toLowerCase() ==
                  myName.toString().toLowerCase());

              if (!alreadyInList) {
                displayList.insert(0, {
                  'name': myName.toString(),
                  'email': myEmail.toString(),
                  'checkIn': attendance.todayAttendance?.formattedCheckInTime ??
                      DateTime.now().toIso8601String(),
                  'status': 'Present',
                });
              }
            }

            // Fallback: If displayList is empty, check allEmployees or default active employee
            if (displayList.isEmpty) {
              for (var emp in allEmployees) {
                if (emp is! Map) continue;
                final st = (emp['status'] ?? emp['attendanceStatus'] ?? '').toString().toLowerCase();
                final hasCheckIn = emp['checkIn'] != null || emp['check_in'] != null;
                if (st == 'present' || st == 'checked_in' || hasCheckIn) {
                  displayList.add({
                    'name': emp['name'] ?? 'Employee',
                    'email': emp['email'] ?? emp['role'] ?? '',
                    'checkIn': emp['checkIn'] ?? emp['check_in'] ?? DateTime.now().toIso8601String(),
                    'status': 'Present',
                  });
                }
              }
              if (displayList.isEmpty && allEmployees.isNotEmpty) {
                for (var emp in allEmployees) {
                  if (emp is Map) {
                    displayList.add({
                      'name': emp['name'] ?? 'Employee',
                      'email': emp['email'] ?? emp['department'] ?? '',
                      'checkIn': DateTime.now().toIso8601String(),
                      'status': 'Present',
                    });
                    break;
                  }
                }
              }
            }
          } else if (statusType == 'leave') {
            for (var leave in attendance.allLeaves) {
              if (leave is! Map) continue;
              String empName =
                  leave['employeeName'] ?? leave['user']?['name'] ?? 'Employee';
              String type = leave['leaveType'] ?? 'Leave';
              displayList.add({
                'name': empName,
                'email': type,
                'status': leave['status'] ?? 'Approved',
              });
            }
          } else if (statusType == 'absent') {
            final presentKeys = <String>{};
            final leaveKeys = <String>{};

            for (var att in todayList) {
              if (att is! Map) continue;
              final st = (att['status'] ?? '').toString().toLowerCase();
              final empObj = att['employee'] ?? att['user'];
              String? id, email, name;
              if (empObj is Map) {
                id = (empObj['_id'] ?? empObj['id'])?.toString();
                email = empObj['email']?.toString();
                name = empObj['name']?.toString();
              } else if (empObj is String) {
                id = empObj;
              }
              id ??= (att['userId'] ?? att['employeeId'] ?? att['user_id'])?.toString();
              email ??= att['email']?.toString();
              name ??= (att['name'] ?? att['employeeName'])?.toString();

              final keys = [id, email, name].where((k) => k != null && k.isNotEmpty).map((k) => k!.trim().toLowerCase()).toSet();
              if (st.contains('leave')) {
                leaveKeys.addAll(keys);
              } else if (!st.contains('absent')) {
                presentKeys.addAll(keys);
              }
            }

            for (var leave in attendance.allLeaves) {
              if (leave is! Map) continue;
              final st = (leave['status'] ?? '').toString().toLowerCase();
              if (st == 'approved') {
                final empObj = leave['user'] ?? leave['employee'];
                String? id, email, name;
                if (empObj is Map) {
                  id = (empObj['_id'] ?? empObj['id'])?.toString();
                  email = empObj['email']?.toString();
                  name = empObj['name']?.toString();
                } else if (empObj is String) {
                  id = empObj;
                }
                id ??= (leave['userId'] ?? leave['employeeId'])?.toString();
                email ??= leave['email']?.toString();
                name ??= (leave['employeeName'] ?? leave['name'])?.toString();

                final keys = [id, email, name].where((k) => k != null && k.isNotEmpty).map((k) => k!.trim().toLowerCase()).toSet();
                leaveKeys.addAll(keys);
              }
            }

            for (var emp in allEmployees) {
              if (emp is! Map) continue;
              final id = (emp['_id'] ?? emp['id'])?.toString().trim().toLowerCase();
              final email = emp['email']?.toString().trim().toLowerCase();
              final name = emp['name']?.toString().trim().toLowerCase();

              final isPresent = (id != null && presentKeys.contains(id)) ||
                  (email != null && presentKeys.contains(email)) ||
                  (name != null && presentKeys.contains(name));

              final isOnLeave = (id != null && leaveKeys.contains(id)) ||
                  (email != null && leaveKeys.contains(email)) ||
                  (name != null && leaveKeys.contains(name));

              if (!isPresent && !isOnLeave) {
                final avatarStr = (emp['avatar'] ?? emp['profilePicture'] ?? emp['image'])?.toString();
                displayList.add({
                  'name': emp['name'] ?? 'Employee',
                  'email': emp['email'] ?? emp['department'] ?? emp['role'] ?? '',
                  'avatar': avatarStr,
                  'status': 'Absent',
                });
              }
            }
          }

          final (statusColor, statusIcon) = switch (statusType) {
            'present' => (const Color(0xFF10B981), Icons.check_circle_rounded),
            'leave' => (const Color(0xFFF59E0B), Icons.calendar_month_rounded),
            _ => (const Color(0xFFEF4444), Icons.cancel_rounded),
          };

          return Container(
            height: MediaQuery.of(context).size.height * 0.65,
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: context.borderCol, width: 1),
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
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(statusIcon, color: statusColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.txtPrimary,
                            ),
                          ),
                          Text(
                            '${displayList.length} employee(s) listed',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.txtMuted,
                            ),
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
                const Divider(height: 24),
                Expanded(
                  child: displayList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_off_rounded,
                                  size: 48,
                                  color: context.txtMuted.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text(
                                'No records found for today',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: context.txtSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          itemCount: displayList.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = displayList[index];
                            final empName = item['name'] ?? 'Employee';
                            final empSub = item['email'] ?? '';
                            final checkInRaw = item['checkIn'];

                            String timeStr = item['status'] ?? '';
                            if (checkInRaw != null) {
                              try {
                                final dt =
                                    DateTime.parse(checkInRaw.toString()).toLocal();
                                timeStr = DateFormat('h:mm a').format(dt);
                              } catch (_) {
                                timeStr = checkInRaw.toString();
                              }
                            }

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.cardLightBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: context.borderCol, width: 1),
                              ),
                              child: Row(
                                children: [
                                  _buildAvatarWidget(item['avatar']?.toString(), empName, 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          empName,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: context.txtPrimary,
                                          ),
                                        ),
                                        if (empSub.isNotEmpty)
                                          Text(
                                            empSub,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: context.txtMuted,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color:
                                              statusColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          item['status'] ?? 'Present',
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (checkInRaw != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          timeStr,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: context.txtMuted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
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
      ),
    );
  }

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
                "Here's what's happening today.",
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
                  Icon(Icons.analytics_rounded, color: Colors.white, size: 30),
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

  // --- Overview Stat Card Component ---
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

  // --- Pending Leaves Section ---
  Widget _buildPendingLeavesSection() {
    final attendance = ref.watch(attendanceProvider);
    final pendingLeaves = attendance.allLeaves.where((l) {
      if (l is! Map) return false;
      return (l['status'] ?? '').toString().toLowerCase() == 'pending';
    }).toList();


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Pending Leaves',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.txtPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: pendingLeaves.isNotEmpty
                    ? const Color(0xFF6366F1)
                    : context.txtMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                pendingLeaves.length.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (pendingLeaves.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderCol),
            ),
            child: Column(
              children: [
                Icon(Icons.event_available_rounded,
                    size: 36, color: context.txtMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 10),
                Text('No pending leaves',
                    style: TextStyle(color: context.txtMuted, fontSize: 14)),
              ],
            ),
          )
        else
          ...pendingLeaves.take(3).map((leave) => _buildPendingLeaveCard(leave)),
      ],
    );
  }

  Widget _buildAvatarWidget(dynamic avatarOrUser, String fallbackText, double radius) {
    String? cleanAvatar = extractAvatarUrl(avatarOrUser);
    if (cleanAvatar != null &&
        cleanAvatar.isNotEmpty &&
        cleanAvatar != 'null' &&
        cleanAvatar != 'undefined') {
      if (cleanAvatar.contains('localhost') ||
          cleanAvatar.contains('127.0.0.1') ||
          cleanAvatar.contains('10.0.2.2')) {
        final apiBase = ApiConstants.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
        cleanAvatar = cleanAvatar.replaceAll(
          RegExp(r'https?://(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?'),
          apiBase,
        );
      }
      // 1. Direct HTTP/HTTPS Network URL
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

      // 2. Base64 Data URI or Raw Base64 String
      if (cleanAvatar.startsWith('data:image/') ||
          (!cleanAvatar.startsWith('/') &&
           !cleanAvatar.startsWith('uploads') &&
           cleanAvatar.length > 50)) {
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

      // 3. Relative Server Path (e.g. /uploads/..., uploads/..., /public/...)
      if (cleanAvatar.startsWith('/') ||
          cleanAvatar.startsWith('uploads') ||
          cleanAvatar.startsWith('public') ||
          cleanAvatar.startsWith('storage') ||
          cleanAvatar.contains('.png') ||
          cleanAvatar.contains('.jpg') ||
          cleanAvatar.contains('.jpeg') ||
          cleanAvatar.contains('.webp')) {
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

      // 4. Local File Path
      if (cleanAvatar.startsWith('file://') || cleanAvatar.startsWith('/') || cleanAvatar.contains(':\\')) {
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

  // --- Pending Leave Card Matching Screenshot ---
  Widget _buildPendingLeaveCard(dynamic leave) {
    if (leave is! Map) return const SizedBox.shrink();
    final emp = leave['employee'];
    final employeeName = (emp is Map ? emp['name'] : null) ??
        leave['employeeName'] ??
        (emp is String ? emp : 'Unknown');
    final empAvatar = emp is Map ? (emp['avatar']?.toString() ?? emp['profilePicture']?.toString() ?? emp['image']?.toString()) : null;
    final leaveType = leave['leaveType'] ?? 'Leave';
    final leaveId = leave['_id']?.toString() ?? '';

    // Format dates from ISO strings
    String dateStr;
    try {
      final start = DateTime.parse(leave['startDate'].toString());
      final end = DateTime.parse(leave['endDate'].toString());
      final fmt = DateFormat('d MMM');
      dateStr = '${fmt.format(start)} - ${fmt.format(end)}';
    } catch (_) {
      dateStr = leave['startDate']?.toString() ?? 'N/A';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.15 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildAvatarWidget(empAvatar, employeeName, 21),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employeeName,
                      style: TextStyle(
                        color: context.txtPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$leaveType  •  $dateStr',
                      style: TextStyle(
                        color: context.txtMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Reject and Approve Buttons Side-by-Side
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _approveLeave(leaveId, 'Rejected'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: const Text(
                    'Reject',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _approveLeave(leaveId, 'Approved'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: const Text(
                    'Approve',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
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

  Future<void> _approveLeave(String leaveId, String status) async {
    if (leaveId.isEmpty || leaveId.startsWith('mock_')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Leave $status'),
          backgroundColor: status == 'Approved' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      );
      return;
    }
    final ok = await ref
        .read(attendanceProvider.notifier)
        .approveRejectLeave(leaveId, status, null);
    if (ok && mounted) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Leave $status successfully'),
          backgroundColor: status == 'Approved'
              ? const Color(0xFF10B981)
              : const Color(0xFFEF4444),
        ),
      );
    }
  }

  // --- Employees Tab ---
  // --- Admin Drawer ---
  Widget _buildAdminDrawer(BuildContext context, WidgetRef ref, AuthState auth) {
    final userName = auth.user?['name'] ?? 'Admin User';
    final userEmail = auth.user?['email'] ?? 'admin@ams.com';
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
                Text(
                  userName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ADMIN',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            accountEmail: Text(
              userEmail,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            currentAccountPicture: _buildAvatarWidget(avatar, userName, 28),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.dashboard_rounded, color: Color(0xFF6366F1)),
                  title: Text('Dashboard', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 0);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF10B981)),
                  title: Text('Add New Employee', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('Onboard staff & assign permissions', style: TextStyle(color: context.txtMuted, fontSize: 11)),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddEmployeeModal(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people_alt_rounded, color: Color(0xFF3B82F6)),
                  title: Text('Employee Directory', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('Manage employees, edit roles', style: TextStyle(color: context.txtMuted, fontSize: 11)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 1);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.access_time_filled_rounded, color: Color(0xFF8B5CF6)),
                  title: Text('Admin Mark Attendance', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('Manual attendance entry', style: TextStyle(color: context.txtMuted, fontSize: 11)),
                  onTap: () {
                    Navigator.pop(context);
                    _showAdminMarkAttendanceModal(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.event_available_rounded, color: Color(0xFFF59E0B)),
                  title: Text('Leave Approvals', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('Approve or reject leave requests', style: TextStyle(color: context.txtMuted, fontSize: 11)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 2);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.insert_chart_rounded, color: Color(0xFF06B6D4)),
                  title: Text('Reports & Analytics', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 3);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.payments_rounded, color: Color(0xFF10B981)),
                  title: Text('Salary & Payroll', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/admin/salary');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.assignment_rounded, color: Color(0xFF6366F1)),
                  title: Text('Projects & Tasks', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/admin/projects');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.holiday_village_rounded, color: Color(0xFFEC4899)),
                  title: Text('Holidays Calendar', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/admin/holidays');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active_rounded, color: Color(0xFFF59E0B)),
                  title: Text('Notifications Center', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/admin/notifications');
                  },
                ),
                Divider(color: context.dividerCol),
                ListTile(
                  leading: const Icon(Icons.badge_rounded, color: Color(0xFF64748B)),
                  title: Text('Switch to Employee View', style: TextStyle(color: context.txtPrimary)),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/employee/dashboard');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_rounded, color: Color(0xFF64748B)),
                  title: Text('Settings & Biometrics', style: TextStyle(color: context.txtPrimary)),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/settings');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                  title: const Text('Logout', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                  onTap: () async {
                    Navigator.pop(context);
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Employees Tab ---
  Widget _buildEmployeesTab() {
    final state = ref.watch(employeeProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Employee Directory',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.txtPrimary,
                    ),
                  ),
                  Text(
                    '${state.employees.length} Total Staff Members',
                    style: TextStyle(fontSize: 12, color: context.txtMuted),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Add Employee', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                onPressed: () => _showAddEmployeeModal(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : state.employees.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 48, color: context.txtMuted),
                          const SizedBox(height: 12),
                          Text('No employees found', style: TextStyle(color: context.txtMuted, fontSize: 16)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Employee'),
                            onPressed: () => _showAddEmployeeModal(context),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref.read(employeeProvider.notifier).loadEmployees(),
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: state.employees.length,
                        itemBuilder: (ctx, i) => _buildEmployeeCard(state.employees[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmployeeCard(dynamic emp) {
    final name = emp['name'] ?? 'Unknown';
    final email = emp['email'] ?? '';
    final dept = emp['department'] ?? 'General';
    final designation = emp['designation'] ?? 'Employee';
    final role = (emp['role'] ?? 'employee').toString().toUpperCase();
    final empId = emp['_id']?.toString() ?? emp['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.15 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: role == 'ADMIN'
                      ? const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)])
                      : AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (name.toString().trim().isNotEmpty ? name.toString().trim()[0] : 'E').toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: context.txtPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: role == 'ADMIN'
                                ? const Color(0xFFEC4899).withValues(alpha: 0.15)
                                : AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            role,
                            style: TextStyle(
                              color: role == 'ADMIN' ? const Color(0xFFEC4899) : AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$designation • $dept',
                      style: TextStyle(color: context.txtSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(color: context.txtMuted, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: context.dividerCol, height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                icon: const Icon(Icons.access_time_rounded, size: 16),
                label: const Text('Mark Attendance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                onPressed: () => _showAdminMarkAttendanceModal(context, preselectedEmpId: empId),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF6366F1)),
                tooltip: 'Edit Employee',
                onPressed: () => _showEditEmployeeModal(context, emp),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                tooltip: 'Delete Employee',
                onPressed: () => _showDeleteEmployeeConfirmation(context, emp),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Modals for Admin Actions ---
  void _showAddEmployeeModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final designationCtrl = TextEditingController();
    String selectedDept = 'IT';
    String selectedRole = 'employee';
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: context.borderCol),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: context.txtMuted.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person_add_alt_1_rounded,
                                color: Color(0xFF6366F1), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add New Employee',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: context.txtPrimary,
                                  ),
                                ),
                                Text(
                                  'Create employee account with full access permissions',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.txtMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: nameCtrl,
                        style: TextStyle(color: context.txtPrimary),
                        decoration: InputDecoration(
                          labelText: 'Full Name *',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter employee name' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: context.txtPrimary),
                        decoration: InputDecoration(
                          labelText: 'Email Address *',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || !v.contains('@')) ? 'Enter valid email' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordCtrl,
                        obscureText: true,
                        style: TextStyle(color: context.txtPrimary),
                        decoration: InputDecoration(
                          labelText: 'Password *',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.length < 4) ? 'Password must be at least 4 chars' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedDept,
                              dropdownColor: context.cardBg,
                              style: TextStyle(color: context.txtPrimary),
                              decoration: InputDecoration(
                                labelText: 'Department',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: ['IT', 'HR', 'Sales', 'Marketing', 'Finance', 'Engineering', 'Operations']
                                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                  .toList(),
                              onChanged: (val) => setModalState(() => selectedDept = val!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedRole,
                              dropdownColor: context.cardBg,
                              style: TextStyle(color: context.txtPrimary),
                              decoration: InputDecoration(
                                labelText: 'Role / Permission',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'employee', child: Text('Employee')),
                                DropdownMenuItem(value: 'admin', child: Text('Admin (All Access)')),
                              ],
                              onChanged: (val) => setModalState(() => selectedRole = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: designationCtrl,
                        style: TextStyle(color: context.txtPrimary),
                        decoration: InputDecoration(
                          labelText: 'Designation / Title',
                          hintText: 'e.g. Software Engineer',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: context.txtPrimary),
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.check_circle_rounded),
                          label: const Text('Add Employee', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            if (formKey.currentState?.validate() ?? false) {
                              Navigator.pop(ctx);
                              final ok = await ref.read(employeeProvider.notifier).addEmployee({
                                'name': nameCtrl.text.trim(),
                                'email': emailCtrl.text.trim(),
                                'password': passwordCtrl.text.trim(),
                                'department': selectedDept,
                                'role': selectedRole,
                                'designation': designationCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim(),
                              });
                              if (ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Employee ${nameCtrl.text} added successfully!'),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditEmployeeModal(BuildContext context, dynamic emp) {
    final empId = emp['_id']?.toString() ?? emp['id']?.toString() ?? '';
    final nameCtrl = TextEditingController(text: emp['name']?.toString() ?? '');
    final emailCtrl = TextEditingController(text: emp['email']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: emp['phone']?.toString() ?? '');
    final designationCtrl = TextEditingController(text: emp['designation']?.toString() ?? '');
    String selectedDept = (emp['department'] != null && emp['department'].toString().isNotEmpty)
        ? emp['department'].toString()
        : 'IT';
    if (!['IT', 'HR', 'Sales', 'Marketing', 'Finance', 'Engineering', 'Operations'].contains(selectedDept)) {
      selectedDept = 'IT';
    }
    String selectedRole = (emp['role']?.toString().toLowerCase() == 'admin') ? 'admin' : 'employee';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: context.borderCol),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.txtMuted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Edit Employee',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: context.txtPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: nameCtrl,
                      style: TextStyle(color: context.txtPrimary),
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      style: TextStyle(color: context.txtPrimary),
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedDept,
                            dropdownColor: context.cardBg,
                            style: TextStyle(color: context.txtPrimary),
                            decoration: InputDecoration(
                              labelText: 'Department',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: ['IT', 'HR', 'Sales', 'Marketing', 'Finance', 'Engineering', 'Operations']
                                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                .toList(),
                            onChanged: (val) => setModalState(() => selectedDept = val!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedRole,
                            dropdownColor: context.cardBg,
                            style: TextStyle(color: context.txtPrimary),
                            decoration: InputDecoration(
                              labelText: 'Role',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'employee', child: Text('Employee')),
                              DropdownMenuItem(value: 'admin', child: Text('Admin')),
                            ],
                            onChanged: (val) => setModalState(() => selectedRole = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: designationCtrl,
                      style: TextStyle(color: context.txtPrimary),
                      decoration: InputDecoration(
                        labelText: 'Designation',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      style: TextStyle(color: context.txtPrimary),
                      decoration: InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Update Employee', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final ok = await ref.read(employeeProvider.notifier).updateEmployee(empId, {
                            'name': nameCtrl.text.trim(),
                            'email': emailCtrl.text.trim(),
                            'department': selectedDept,
                            'role': selectedRole,
                            'designation': designationCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                          });
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Employee details updated!'),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteEmployeeConfirmation(BuildContext context, dynamic emp) {
    final empId = emp['_id']?.toString() ?? emp['id']?.toString() ?? '';
    final name = emp['name'] ?? 'Employee';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
              const SizedBox(width: 10),
              Text('Delete Employee', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Are you sure you want to remove $name from the system? This action cannot be undone.',
            style: TextStyle(color: context.txtSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: context.txtMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await ref.read(employeeProvider.notifier).deleteEmployee(empId);
                if (ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$name removed successfully'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showAdminMarkAttendanceModal(BuildContext context, {String? preselectedEmpId}) {
    final employees = ref.read(employeeProvider).employees;
    if (employees.isEmpty) {
      ref.read(employeeProvider.notifier).loadEmployees();
    }
    String selectedEmpId = preselectedEmpId ??
        (employees.isNotEmpty
            ? (employees.first['_id']?.toString() ?? employees.first['id']?.toString() ?? '')
            : '');
    String selectedStatus = 'Present';
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final empList = ref.watch(employeeProvider).employees;
            if (selectedEmpId.isEmpty && empList.isNotEmpty) {
              selectedEmpId = empList.first['_id']?.toString() ?? empList.first['id']?.toString() ?? '';
            }

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: context.borderCol),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.txtMuted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.access_time_filled_rounded,
                              color: Color(0xFF10B981), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Admin Mark Attendance',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: context.txtPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: selectedEmpId.isNotEmpty ? selectedEmpId : null,
                      dropdownColor: context.cardBg,
                      style: TextStyle(color: context.txtPrimary),
                      decoration: InputDecoration(
                        labelText: 'Select Employee',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.person_search_rounded),
                      ),
                      items: empList.map<DropdownMenuItem<String>>((e) {
                        final id = e['_id']?.toString() ?? e['id']?.toString() ?? '';
                        final name = e['name'] ?? 'Employee';
                        final dept = e['department'] ?? '';
                        return DropdownMenuItem(
                          value: id,
                          child: Text('$name ($dept)'),
                        );
                      }).toList(),
                      onChanged: (val) => setModalState(() => selectedEmpId = val ?? ''),
                    ),
                    const SizedBox(height: 16),
                    Text('Attendance Status', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Present', 'Late', 'Half Day', 'Absent'].map((st) {
                        final isSel = selectedStatus == st;
                        Color c;
                        if (st == 'Present') {
                          c = const Color(0xFF10B981);
                        } else if (st == 'Late') {
                          c = const Color(0xFFF59E0B);
                        } else if (st == 'Half Day') {
                          c = const Color(0xFF6366F1);
                        } else {
                          c = const Color(0xFFEF4444);
                        }

                        return ChoiceChip(
                          label: Text(st),
                          selected: isSel,
                          selectedColor: c,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : context.txtPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => setModalState(() => selectedStatus = st),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: notesCtrl,
                      style: TextStyle(color: context.txtPrimary),
                      decoration: InputDecoration(
                        labelText: 'Admin Remarks / Reason',
                        hintText: 'e.g. On-site assignment, Approved delay',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('Submit Attendance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          if (selectedEmpId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select an employee')),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          final ok = await ref.read(attendanceProvider.notifier).adminMarkAttendance(
                            employeeId: selectedEmpId,
                            status: selectedStatus,
                            notes: notesCtrl.text.trim(),
                          );
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Attendance marked as $selectedStatus'),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Leaves Tab ---
  Widget _buildLeaveApprovalTab() {
    final attendance = ref.watch(attendanceProvider);
    final leaves = attendance.allLeaves;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Text(
                'Leave Requests',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.txtPrimary),
              ),
              const Spacer(),
              Text('${leaves.length} items',
                  style: TextStyle(color: context.txtMuted, fontSize: 13)),
            ],
          ),
        ),
        Expanded(
          child: attendance.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : leaves.isEmpty
                  ? Center(
                      child: Text('No leave requests',
                          style: TextStyle(color: context.txtMuted)))
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () =>
                          ref.read(attendanceProvider.notifier).loadAllLeaves(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: leaves.length,
                        itemBuilder: (ctx, i) =>
                            _buildPendingLeaveCard(leaves[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  // --- Reports Tab ---
  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reports & Analytics',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: context.txtPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildMoreItem(Icons.analytics_outlined, 'Attendance Overview',
              () => context.go('/admin/analytics')),
          _buildMoreItem(Icons.folder_outlined, 'Project Progress',
              () => context.go('/admin/projects')),
          _buildMoreItem(Icons.payment_outlined, 'Salary Reports',
              () => context.go('/admin/salary')),
          _buildMoreItem(Icons.holiday_village_outlined, 'Holiday Calendar',
              () => context.go('/admin/holidays')),
        ],
      ),
    );
  }

  // --- More Tab ---
  Widget _buildMoreTab() {
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
          // Theme Switch
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              tileColor: context.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: context.borderCol),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (ref.watch(themeProvider) == ThemeMode.dark
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFF6366F1))
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  ref.watch(themeProvider) == ThemeMode.dark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  color: ref.watch(themeProvider) == ThemeMode.dark
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              title: Text(
                ref.watch(themeProvider) == ThemeMode.dark ? 'Light Mode' : 'Dark Mode',
                style: TextStyle(
                    color: context.txtPrimary, fontWeight: FontWeight.w500),
              ),
              trailing: Switch.adaptive(
                value: ref.watch(themeProvider) == ThemeMode.dark,
                activeTrackColor: const Color(0xFF6366F1),
                onChanged: (_) {
                  ref.read(themeProvider.notifier).toggleTheme();
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: context.dividerCol),
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
        tileColor: context.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: context.borderCol),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(label,
            style: TextStyle(
                color: context.txtPrimary, fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.chevron_right,
            color: context.txtMuted, size: 20),
        onTap: onTap,
      ),
    );
  }

  // --- Bottom Navigation Bar with 5 Items ---
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
        selectedItemColor: const Color(0xFF6366F1),
        unselectedItemColor: context.txtMuted,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (i) {
          setState(() => _selectedIndex = i);
          if (i == 2) {
            ref.read(attendanceProvider.notifier).loadAllLeaves();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline_rounded),
            activeIcon: Icon(Icons.people_rounded),
            label: 'Employees',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business_center_outlined),
            activeIcon: Icon(Icons.business_center_rounded),
            label: 'Leaves',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insert_drive_file_outlined),
            activeIcon: Icon(Icons.insert_drive_file_rounded),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz_rounded),
            activeIcon: Icon(Icons.more_horiz_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

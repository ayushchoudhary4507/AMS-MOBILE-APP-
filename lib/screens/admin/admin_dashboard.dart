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
import '../../providers/dashboard_config_provider.dart';
import '../../models/dashboard_card_config.dart';
import '../shared/notifications_screen.dart';
import '../chat/chat_list_screen.dart';
import '../employee/employee_dashboard.dart';
import '../../widgets/common/app_avatar.dart';
import '../../widgets/common/photo_viewer_dialog.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  int _selectedIndex = 0;
  String _leaveFilter = 'All';
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
      ref.read(attendanceProvider.notifier).loadAllLeaves();
      ref.read(dashboardConfigProvider.notifier).loadConfig();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(notifScreenProvider);
    final auth = ref.watch(authProvider);
    final rawUser = auth.user;
    final Map<String, dynamic>? userMap =
        rawUser is Map ? Map<String, dynamic>.from(rawUser as Map) : null;
    final adminName = userMap?['name']?.toString() ??
        userMap?['fullName']?.toString() ??
        'Admin';
    final today = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildAdminDrawer(context, ref, auth),
      body: Container(
        decoration: BoxDecoration(gradient: context.mainBgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(adminName, today),
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
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
      decoration: BoxDecoration(
        color: context.isDark
            ? Colors.transparent
            : context.cardBg.withValues(alpha: 0.85),
        border: context.isDark
            ? null
            : Border(
                bottom: BorderSide(
                  color: context.borderCol.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
      ),
      child: Row(
        children: [
          // Drawer / Menu Icon
          Builder(
            builder: (ctx) => IconButton(
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              icon: Icon(Icons.menu_rounded, color: context.txtPrimary, size: 24),
              onPressed: () {
                try {
                  Scaffold.of(ctx).openDrawer();
                } catch (_) {
                  _scaffoldKey.currentState?.openDrawer();
                }
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Admin Panel',
                  style: TextStyle(
                    fontSize: 18,
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
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: context.txtMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          // Theme Mode Toggle (Light / Dark)
          IconButton(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: const EdgeInsets.all(6),
            icon: Icon(
              ref.watch(themeProvider) == ThemeMode.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: ref.watch(themeProvider) == ThemeMode.dark
                  ? const Color(0xFFFBBF24)
                  : const Color(0xFF6366F1),
              size: 21,
            ),
            tooltip: ref.watch(themeProvider) == ThemeMode.dark
                ? 'Switch to Light Mode'
                : 'Switch to Dark Mode',
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme();
            },
          ),
          // QR Attendance Session Generator
          IconButton(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: const EdgeInsets.all(6),
            icon: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Color(0xFF6366F1),
              size: 21,
            ),
            tooltip: 'Attendance QR Session',
            onPressed: () => context.push('/admin/attendance-qr'),
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
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: const EdgeInsets.all(6),
                    icon: Icon(
                      Icons.notifications_none_rounded,
                      color: context.txtPrimary,
                      size: 22,
                    ),
                    onPressed: () => context.go('/admin/notifications'),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 15,
                          minHeight: 15,
                        ),
                        child: Text(
                          count > 99 ? '99+' : count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
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
          // Logout Button
          IconButton(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: const EdgeInsets.all(6),
            icon: const Icon(
              Icons.logout_rounded,
              color: Color(0xFFEF4444),
              size: 21,
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
    final activeNav = ref.watch(dashboardConfigProvider).enabledBottomNav;
    final currentIndex = _selectedIndex < activeNav.length ? _selectedIndex : 0;
    final currentTabId = activeNav[currentIndex].id.toLowerCase();

    switch (currentTabId) {
      case 'dashboard':
        return _buildDashboardTab();
      case 'employees':
        return _buildEmployeesTab();
      case 'leaves':
      case 'pending_leaves':
        return _buildLeaveApprovalTab();
      case 'messages':
      case 'chat':
        return const ChatListScreen(showAppBar: false);
      case 'more':
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
    final allEmps = employees.employees;

    final todayList = attendance.todayAllAttendance.isNotEmpty
        ? attendance.todayAllAttendance
        : (attendance.todayAttendance != null
              ? [attendance.todayAttendance!.toJson()]
              : []);

    // todayAllAttendance now contains only present-today employees from API
    // Each record has: { name, email, userId, employeeId, status, checkIn, checkOut, employee: {...} }
    final presentKeys = <String>{};
    final activePresentKeys = <String>{};
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
      }
      id ??= (att['userId'] ?? att['employeeId'])?.toString();
      email ??= att['email']?.toString();
      name ??= att['name']?.toString();

      final keys = [id, email, name]
          .where((k) => k != null && k.isNotEmpty)
          .map((k) => k!.trim().toLowerCase())
          .toSet();

      if (st.contains('leave')) {
        leaveKeys.addAll(keys);
      } else {
        presentKeys.addAll(keys);

        // Check if employee has checked out (completed shift)
        final cOut =
            att['checkOut'] ??
            att['checkOutTime'] ??
            att['check_out'] ??
            att['outTime'];
        final isCheckedOut =
            (cOut != null &&
            cOut.toString().trim().isNotEmpty &&
            cOut.toString() != 'null');
        if (!isCheckedOut) {
          activePresentKeys.addAll(keys);
        }
      }
    }

    for (var leave in attendance.allLeaves) {
      if (isLeaveActiveToday(leave)) {
        final empObj =
            leave['employeeId'] ?? leave['user'] ?? leave['employee'];
        String? id, email, name;
        if (empObj is Map) {
          id = (empObj['_id'] ?? empObj['id'])?.toString();
          email = empObj['email']?.toString();
          name = empObj['name']?.toString();
        }
        id ??=
            (leave['userId'] ??
                    (leave['employeeId'] is String
                        ? leave['employeeId']
                        : null))
                ?.toString();
        email ??= leave['email']?.toString();
        name ??= (leave['employeeName'] ?? leave['name'])?.toString();

        final keys = [id, email, name]
            .where((k) => k != null && k.isNotEmpty)
            .map((k) => k!.trim().toLowerCase())
            .toSet();
        leaveKeys.addAll(keys);
      }
    }

    int realPresent = 0;
    int realLeave = 0;
    int realAbsent = 0;

    if (allEmps.isNotEmpty) {
      for (var emp in allEmps) {
        if (emp is! Map) continue;
        final id = (emp['_id'] ?? emp['id'])?.toString().trim().toLowerCase();
        final email = emp['email']?.toString().trim().toLowerCase();
        final name = emp['name']?.toString().trim().toLowerCase();

        final isPresent =
            (id != null && presentKeys.contains(id)) ||
            (email != null && presentKeys.contains(email)) ||
            (name != null && presentKeys.contains(name));

        final isOnLeave =
            (id != null && leaveKeys.contains(id)) ||
            (email != null && leaveKeys.contains(email)) ||
            (name != null && leaveKeys.contains(name));

        if (isPresent) {
          realPresent++;
        } else if (isOnLeave) {
          realLeave++;
        } else {
          realAbsent++;
        }
      }
    } else {
      // If allEmps is empty, count unique records from todayList
      final uniquePresentIds = <String>{};
      for (final att in todayList) {
        if (att is! Map) continue;
        final st = (att['status'] ?? '').toString().toLowerCase();
        if (st.contains('absent') || st.contains('leave')) continue;
        final uid = (att['userId'] ?? att['employeeId'] ?? att['_id'] ?? att['email'] ?? att['name'])?.toString();
        if (uid != null && uid.isNotEmpty) {
          uniquePresentIds.add(uid.toLowerCase());
        }
      }
      realPresent = uniquePresentIds.length;
      realLeave = leaveKeys.length;
      final statsAbsent = int.tryParse(
        stats?['absentCount']?.toString() ?? stats?['absent']?.toString() ?? '',
      );
      realAbsent = statsAbsent ?? 0;
    }

    final totalEmpCount = allEmps.isNotEmpty
        ? allEmps.length
        : (int.tryParse(
                stats?['totalEmployees']?.toString() ??
                    stats?['total']?.toString() ??
                    stats?['count']?.toString() ??
                    '',
              ) ??
              (realPresent + realLeave + realAbsent));

    // Ensure present count never exceeds total employee count
    if (totalEmpCount > 0 && realPresent > totalEmpCount) {
      realPresent = totalEmpCount;
    }
    if (totalEmpCount >= realPresent + realLeave) {
      realAbsent = totalEmpCount - realPresent - realLeave;
    }

    final totalEmp = totalEmpCount.toString();
    final presentCount = realPresent.toString();
    final leaveCount = realLeave.toString();
    final absentCount = realAbsent.toString();

    final activeDashboardCards = ref.watch(dashboardConfigProvider).enabledCards;

    return RefreshIndicator(
      color: const Color(0xFF6366F1),
      onRefresh: () async {
        await Future.wait([
          ref.read(attendanceProvider.notifier).loadStats(),
          ref.read(attendanceProvider.notifier).loadTodayAllAttendance(),
          ref.read(employeeProvider.notifier).loadEmployees(),
          ref.read(attendanceProvider.notifier).loadAllLeaves(),
          ref.read(dashboardConfigProvider.notifier).loadConfig(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Welcome Banner Hero Card
          _buildWelcomeBanner(
            authName: (ref.watch(authProvider).user is Map
                    ? (ref.watch(authProvider).user as Map)['name']
                    : null)
                ?.toString() ??
                'Admin',
          ),
          const SizedBox(height: 20),

          // 2. Attendance QR Session Generator Hero Card
          _buildAttendanceQRSessionCard(),

          const SizedBox(height: 24),

          // 3. Overview Section Header & Stat Cards
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
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: context.txtMuted,
                ),
                onPressed: () {
                  ref.read(attendanceProvider.notifier).loadStats();
                  ref.read(employeeProvider.notifier).loadEmployees();
                  ref.read(dashboardConfigProvider.notifier).loadConfig();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dynamic Overview Stat Cards Grid / List (Powered by Dashboard Config)
          if (activeDashboardCards.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: context.borderCol.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.visibility_off_rounded,
                    size: 28,
                    color: context.txtMuted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No overview cards enabled',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.txtPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enable cards from Admin Panel > App Dashboard Settings',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.txtMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: activeDashboardCards.length,
              itemBuilder: (context, index) {
                final card = activeDashboardCards[index];
                return _buildDynamicOverviewCardItem(
                  card: card,
                  totalEmp: totalEmp,
                  presentCount: presentCount,
                  leaveCount: leaveCount,
                  absentCount: absentCount,
                );
              },
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                _buildQuickActionButton(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Attendance QR',
                  color: const Color(0xFF6366F1),
                  onTap: () => context.push('/admin/attendance-qr'),
                ),
                const SizedBox(width: 10),
                _buildQuickActionButton(
                  icon: Icons.face_retouching_natural_rounded,
                  label: 'Face Attendance',
                  color: const Color(0xFF06B6D4),
                  onTap: () => context.push('/admin/face-attendance'),
                ),
                const SizedBox(width: 10),
                _buildQuickActionButton(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Add Employee',
                  color: const Color(0xFF4F46E5),
                  onTap: () => _showAddEmployeeModal(context),
                ),
                const SizedBox(width: 10),
                _buildQuickActionButton(
                  icon: Icons.access_time_filled_rounded,
                  label: 'Mark Attendance',
                  color: const Color(0xFF10B981),
                  onTap: () => _showAdminMarkAttendanceModal(context),
                ),
                const SizedBox(width: 10),
                _buildQuickActionButton(
                  icon: Icons.event_available_rounded,
                  label: 'Leaves',
                  color: const Color(0xFFF59E0B),
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
                const SizedBox(width: 10),
                _buildQuickActionButton(
                  icon: Icons.insert_chart_rounded,
                  label: 'Reports',
                  color: const Color(0xFF06B6D4),
                  onTap: () => setState(() => _selectedIndex = 3),
                ),
              ],
            ),
          ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
        ],
      ),
      ),
    );
  }

  Widget _buildAttendanceQRSessionCard() {
    final attendance = ref.watch(attendanceProvider);
    final session = attendance.activeSession;
    final isActive = session != null && session.isActive;
    final scannedCount = session?.scannedCount ?? (session?.scannedEmployees.length ?? 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? const Color(0xFF6366F1).withValues(alpha: 0.5)
              : context.borderCol,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isActive ? const Color(0xFF4F46E5) : Colors.black)
                .withValues(alpha: context.isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Color(0xFF4F46E5),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance QR Session',
                      style: TextStyle(
                        color: context.txtPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isActive
                          ? 'Expires in: ${session.formattedRemainingTime}'
                          : 'Status: Inactive',
                      style: TextStyle(
                        color: isActive
                            ? const Color(0xFF4F46E5)
                            : context.txtMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  isActive ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                    color: isActive
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.borderCol),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.how_to_reg_rounded,
                        size: 15,
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Scanned: $scannedCount',
                          style: TextStyle(
                            color: context.txtPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/admin/attendance-qr'),
                  icon: Icon(
                    isActive ? Icons.qr_code_2_rounded : Icons.play_arrow_rounded,
                    size: 17,
                  ),
                  label: Text(
                    isActive ? 'Display QR' : 'Start Session',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAttendanceModal(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String statusType,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String activeCategory =
            statusType; // 'absent', 'present', 'leave', or 'all'

        return StatefulBuilder(
          builder: (context, setModalState) {
            final attendance = ref.watch(attendanceProvider);
            final employeeState = ref.watch(employeeProvider);
            final todayList = attendance.todayAllAttendance;
            final allEmployees = employeeState.employees;

            final presentList = <Map<String, dynamic>>[];
            final leaveList = <Map<String, dynamic>>[];
            final absentList = <Map<String, dynamic>>[];
            final allList = <Map<String, dynamic>>[];

            final presentKeys = <String>{};
            final leaveKeys = <String>{};

            // 1. Collect Present records from today's attendance (already pre-parsed by provider)
            final seenPresentEmpKeys = <String>{};
            for (var att in todayList) {
              if (att is! Map) continue;
              final st = (att['status'] ?? '').toString().toLowerCase();
              if (st.contains('absent')) continue;

              final empObj = att['employee'] ?? att['user'];
              String? id, email, name, avatar;
              if (empObj is Map) {
                id = (empObj['_id'] ?? empObj['id'])?.toString();
                email = empObj['email']?.toString();
                name = empObj['name']?.toString();
                avatar = extractAvatarUrl(empObj);
              }
              id ??= (att['userId'] ?? att['employeeId'])?.toString();
              email ??= att['email']?.toString();
              name ??= att['name']?.toString();
              avatar ??= extractAvatarUrl(att);

              // Resolve real name and avatar from allEmployees if missing or generic
              if (allEmployees.isNotEmpty) {
                for (final e in allEmployees) {
                  if (e is! Map) continue;
                  final eId = (e['_id'] ?? e['id'])?.toString();
                  final eEmail = e['email']?.toString();
                  final eName = e['name']?.toString();
                  if ((id != null && id.isNotEmpty && id == eId) ||
                      (email != null && email.isNotEmpty && email.toLowerCase() == eEmail?.toLowerCase())) {
                    if (eName != null && eName.isNotEmpty) name = eName;
                    if (eEmail != null && eEmail.isNotEmpty) email = eEmail;
                    avatar ??= extractAvatarUrl(e);
                    break;
                  }
                }
              }

              final keys = [id, email, name]
                  .where((k) => k != null && k.isNotEmpty)
                  .map((k) => k!.trim().toLowerCase())
                  .toSet();

              if (st.contains('leave')) {
                leaveKeys.addAll(keys);
              } else {
                presentKeys.addAll(keys);
                final cIn = att['checkIn'] ??
                    att['checkInTime'] ??
                    att['check_in'] ??
                    att['inTime'] ??
                    (att['raw'] is Map ? (att['raw']['checkInTime'] ?? att['raw']['checkIn'] ?? att['raw']['inTime'] ?? att['raw']['date']) : null) ??
                    att['date'];
                final cOut = att['checkOut'] ??
                    att['checkOutTime'] ??
                    att['check_out'] ??
                    att['outTime'] ??
                    (att['raw'] is Map ? (att['raw']['checkOutTime'] ?? att['raw']['checkOut'] ?? att['raw']['outTime']) : null);
                final method = att['attendanceMethod'] ??
                    att['verificationMethod'] ??
                    (att['faceImage'] != null ? 'Face Lock Biometric' : null);

                final empDedupKey = (id ?? email ?? (name ?? 'emp')).toLowerCase();
                if (!seenPresentEmpKeys.contains(empDedupKey)) {
                  seenPresentEmpKeys.add(empDedupKey);
                  presentList.add({
                    'id': id,
                    'userId': id,
                    'name': name ?? 'Employee',
                    'email': email ?? '',
                    'avatar': avatar,
                    'status': 'Present',
                    'method': method,
                    'checkIn': cIn,
                    'checkInTime': cIn,
                    'checkOut': cOut,
                    'checkOutTime': cOut,
                    'raw': att,
                  });
                }
              }
            }

            // 2. Collect Leave records (Active Today only)
            final addedLeaveEmpKeys = <String>{};
            for (var leave in attendance.allLeaves) {
              if (isLeaveActiveToday(leave)) {
                final (name, avatar) = _extractLeaveEmployeeInfo(
                  leave,
                  allEmployees,
                );
                final empObj =
                    leave['employeeId'] ?? leave['user'] ?? leave['employee'];
                String? id, email;
                if (empObj is Map) {
                  id = (empObj['_id'] ?? empObj['id'])?.toString();
                  email = empObj['email']?.toString();
                }
                id ??=
                    (leave['userId'] ??
                            (leave['employeeId'] is String
                                ? leave['employeeId']
                                : null))
                        ?.toString();
                email ??= leave['email']?.toString();

                final keys = [id, email, name]
                    .where((k) => k != null && k.isNotEmpty)
                    .map((k) => k!.trim().toLowerCase())
                    .toSet();
                leaveKeys.addAll(keys);

                final empKey =
                    (id ?? email ?? (name.isNotEmpty ? name : 'emp'))
                        .toLowerCase();
                if (!addedLeaveEmpKeys.contains(empKey)) {
                  addedLeaveEmpKeys.add(empKey);
                  leaveList.add({
                    'name': name,
                    'email':
                        leave['email'] ??
                        leave['leaveType'] ??
                        'Approved Leave',
                    'avatar': avatar,
                    'status': 'On Leave',
                    'note': leave['leaveType'] ?? 'Approved Leave',
                  });
                }
              }
            }

            // 3. Cross-reference all employees to calculate Absent and All status
            for (var emp in allEmployees) {
              if (emp is! Map) continue;
              final id = (emp['_id'] ?? emp['id'])
                  ?.toString()
                  .trim()
                  .toLowerCase();
              final email = emp['email']?.toString().trim().toLowerCase();
              final name = emp['name']?.toString().trim().toLowerCase();
              final avatar = extractAvatarUrl(emp);

              final isPresent =
                  (id != null && presentKeys.contains(id)) ||
                  (email != null && presentKeys.contains(email)) ||
                  (name != null && presentKeys.contains(name));

              final isOnLeave =
                  (id != null && leaveKeys.contains(id)) ||
                  (email != null && leaveKeys.contains(email)) ||
                  (name != null && leaveKeys.contains(name));

              final empName = emp['name'] ?? 'Employee';
              final empSub =
                  emp['email'] ?? emp['department'] ?? emp['role'] ?? '';

              if (isPresent) {
                final empCheckIn = emp['checkInTime'] ??
                    emp['checkIn'] ??
                    (emp['attendanceToday'] is Map ? (emp['attendanceToday']['checkInTime'] ?? emp['attendanceToday']['checkIn']) : null);
                final match = presentList.firstWhere(
                  (p) =>
                      ((id != null && (p['id']?.toString().toLowerCase() == id || p['userId']?.toString().toLowerCase() == id)) ||
                      (email != null &&
                          p['email']?.toString().toLowerCase() == email) ||
                      (name != null &&
                          p['name']?.toString().toLowerCase() == name)),
                  orElse: () => {
                    'name': empName,
                    'email': empSub,
                    'avatar': avatar,
                    'status': 'Present',
                    'checkIn': empCheckIn,
                    'checkInTime': empCheckIn,
                  },
                );
                if (!allList.contains(match)) {
                  allList.add(match);
                }
                // Ensure presentList has real name, photo and checkIn
                final pIdx = presentList.indexOf(match);
                if (pIdx >= 0) {
                  if (presentList[pIdx]['name'] == 'Employee' || presentList[pIdx]['name'] == null) {
                    presentList[pIdx]['name'] = empName;
                  }
                  if (presentList[pIdx]['avatar'] == null) {
                    presentList[pIdx]['avatar'] = avatar;
                  }
                  if (presentList[pIdx]['checkIn'] == null && empCheckIn != null) {
                    presentList[pIdx]['checkIn'] = empCheckIn;
                    presentList[pIdx]['checkInTime'] = empCheckIn;
                  }
                }
              } else if (isOnLeave) {
                final match = leaveList.firstWhere(
                  (l) =>
                      ((email != null &&
                          l['email']?.toString().toLowerCase() == email) ||
                      (name != null &&
                          l['name']?.toString().toLowerCase() == name)),
                  orElse: () => {
                    'name': empName,
                    'email': empSub,
                    'avatar': avatar,
                    'status': 'On Leave',
                    'note': 'Approved Leave',
                  },
                );
                if (!allList.contains(match)) {
                  allList.add(match);
                }
              } else {
                final absentItem = {
                  'name': empName,
                  'email': empSub,
                  'avatar': avatar,
                  'status': 'Absent',
                  'note': 'Attendance Not Marked Today',
                };
                absentList.add(absentItem);
                allList.add(absentItem);
              }
            }

            // Fallback for presentList if empty but present employees exist
            if (presentList.isEmpty) {
              presentList.addAll(
                allList.where((e) => e['status'] == 'Present'),
              );
            }

            // Determine active list for activeCategory
            List<Map<String, dynamic>> activeList;
            if (activeCategory == 'present') {
              activeList = presentList;
            } else if (activeCategory == 'leave') {
              activeList = leaveList;
            } else if (activeCategory == 'all') {
              activeList = allList;
            } else {
              activeList = absentList;
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.70,
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
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
                            color: const Color(
                              0xFF6366F1,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.people_alt_rounded,
                            color: Color(0xFF6366F1),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Attendance Overview',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: context.txtPrimary,
                              ),
                            ),
                            Text(
                              '${activeList.length} employee(s) listed',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.txtMuted,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: context.txtMuted,
                          ),
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
                        _buildAdminModalChip(
                          label: 'Absent (${absentList.length})',
                          isSelected: activeCategory == 'absent',
                          color: const Color(0xFFEF4444),
                          onTap: () =>
                              setModalState(() => activeCategory = 'absent'),
                        ),
                        const SizedBox(width: 8),
                        _buildAdminModalChip(
                          label: 'Present / Not Absent (${presentList.length})',
                          isSelected: activeCategory == 'present',
                          color: const Color(0xFF10B981),
                          onTap: () =>
                              setModalState(() => activeCategory = 'present'),
                        ),
                        const SizedBox(width: 8),
                        _buildAdminModalChip(
                          label: 'On Leave (${leaveList.length})',
                          isSelected: activeCategory == 'leave',
                          color: const Color(0xFFF59E0B),
                          onTap: () =>
                              setModalState(() => activeCategory = 'leave'),
                        ),
                        const SizedBox(width: 8),
                        _buildAdminModalChip(
                          label: 'All (${allList.length})',
                          isSelected: activeCategory == 'all',
                          color: const Color(0xFF6366F1),
                          onTap: () =>
                              setModalState(() => activeCategory = 'all'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 20),

                  // Active List Display
                  Expanded(
                    child: activeList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 48,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No records for this category today',
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
                              horizontal: 20,
                              vertical: 8,
                            ),
                            itemCount: activeList.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = activeList[index];
                              final empName = item['name'] ?? 'Employee';
                              final empSub = item['email'] ?? '';
                              final statusStr = item['status'] ?? 'Absent';

                              final (statusBg, statusFg) = switch (statusStr
                                  .toLowerCase()) {
                                'present' => (
                                  const Color(0xFFDCFCE7),
                                  const Color(0xFF10B981),
                                ),
                                'on leave' || 'leave' => (
                                  const Color(0xFFFEF3C7),
                                  const Color(0xFFF59E0B),
                                ),
                                _ => (
                                  const Color(0xFFFEE2E2),
                                  const Color(0xFFEF4444),
                                ),
                              };

                              return InkWell(
                                onTap: () =>
                                    _showEmployeeAttendanceDetailsModal(item),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: context.cardLightBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: context.borderCol,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      _buildAvatarWidget(
                                        item['avatar'],
                                        empName,
                                        20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                                  fontSize: 11,
                                                  color: context.txtMuted,
                                                ),
                                              ),
                                            const SizedBox(height: 4),
                                            if (statusStr.toLowerCase() ==
                                                'present') ...[
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 4,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.login_rounded,
                                                        size: 12,
                                                        color: Color(0xFF10B981),
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        'In: ${_formatTimeStr(item['checkIn'])}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(0xFF10B981),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.calendar_today_rounded,
                                                        size: 11,
                                                        color: Color(0xFF6366F1),
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        _formatDateStr(item['checkIn'] ?? item['date']),
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: context.txtMuted,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (item['method'] != null &&
                                                      item['method'].toString().isNotEmpty)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 6, vertical: 1.5),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        item['method'].toString(),
                                                        style: const TextStyle(
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.w600,
                                                          color: Color(0xFF6366F1),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ] else if (statusStr.toLowerCase() ==
                                                'absent') ...[
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.cancel_outlined,
                                                    size: 12,
                                                    color: Color(0xFFEF4444),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      item['note'] ??
                                                          'Attendance Not Marked Today',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Color(
                                                          0xFFEF4444,
                                                        ),
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ] else ...[
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.event_busy_rounded,
                                                    size: 12,
                                                    color: Color(0xFFF59E0B),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      item['note'] ??
                                                          'On Approved Leave',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Color(
                                                          0xFFF59E0B,
                                                        ),
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusBg,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          statusStr,
                                          style: TextStyle(
                                            color: statusFg,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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

  (String, String?) _extractLeaveEmployeeInfo(
    dynamic leave,
    List<dynamic> allEmployees,
  ) {
    if (leave is! Map) return ('Employee', null);

    final empObj =
        leave['employeeId'] ??
        leave['employee'] ??
        leave['user'] ??
        leave['userId'];

    String? name;
    String? avatar;
    String? empId;
    String? email;

    if (empObj is Map) {
      name = (empObj['name'] ?? empObj['employeeName'] ?? empObj['userName'])
          ?.toString();
      avatar = extractAvatarUrl(empObj);
      empId = (empObj['_id'] ?? empObj['id'])?.toString();
      email = empObj['email']?.toString();
    } else if (empObj is String && empObj.trim().isNotEmpty) {
      empId = empObj.trim();
      if (!empId.startsWith('6') && empId.length < 20) {
        name = empId;
      }
    }

    name ??= (leave['employeeName'] ?? leave['userName'] ?? leave['name'])
        ?.toString();
    avatar ??= extractAvatarUrl(leave);
    email ??= leave['email']?.toString();

    if ((name == null || name.isEmpty || name == 'Unknown') &&
        allEmployees.isNotEmpty) {
      final searchId = (empId ?? leave['userId'] ?? leave['employeeId'])
          ?.toString()
          .trim()
          .toLowerCase();
      final searchEmail = email?.trim().toLowerCase();

      for (var emp in allEmployees) {
        if (emp is! Map) continue;
        final id = (emp['_id'] ?? emp['id'])?.toString().trim().toLowerCase();
        final eId = emp['employeeId']?.toString().trim().toLowerCase();
        final mail = emp['email']?.toString().trim().toLowerCase();

        if ((searchId != null && (searchId == id || searchId == eId)) ||
            (searchEmail != null && searchEmail == mail)) {
          name = emp['name']?.toString();
          avatar ??= extractAvatarUrl(emp);
          break;
        }
      }
    }

    final finalName =
        (name != null && name.trim().isNotEmpty && name != 'Unknown')
        ? name.trim()
        : 'Employee';
    return (finalName, avatar);
  }

  String _formatTimeStr(dynamic raw) {
    if (raw == null ||
        raw.toString().trim().isEmpty ||
        raw.toString() == 'null') {
      return '--:--';
    }
    try {
      final dt = DateTime.parse(raw.toString());
      return DateFormat('hh:mm a').format(dt.toLocal());
    } catch (_) {
      final str = raw.toString().trim();
      if (str.length > 20) return str.substring(0, 10);
      return str;
    }
  }

  String _formatDateStr(dynamic raw) {
    if (raw == null ||
        raw.toString().trim().isEmpty ||
        raw.toString() == 'null') {
      return DateFormat('dd MMM yyyy').format(DateTime.now());
    }
    try {
      final dt = DateTime.parse(raw.toString());
      return DateFormat('dd MMM yyyy').format(dt.toLocal());
    } catch (_) {
      return DateFormat('dd MMM yyyy').format(DateTime.now());
    }
  }

  String _calculateDurationStr(dynamic checkInRaw, dynamic checkOutRaw) {
    if (checkInRaw == null ||
        checkInRaw.toString().isEmpty ||
        checkInRaw.toString() == 'null') {
      return '0 hrs 0 mins';
    }
    try {
      final start = DateTime.parse(checkInRaw.toString());
      final isOutMarked =
          (checkOutRaw != null &&
          checkOutRaw.toString().isNotEmpty &&
          checkOutRaw.toString() != 'null');

      if (!isOutMarked) {
        final now = DateTime.now();
        final isToday =
            start.year == now.year &&
            start.month == now.month &&
            start.day == now.day;
        if (isToday) {
          final diff = now.difference(start);
          final hours = diff.inHours;
          final mins = diff.inMinutes % 60;
          if (hours > 0) {
            return '$hours hrs $mins mins (Active Now)';
          } else {
            return '$mins mins (Active Now)';
          }
        } else {
          return 'Shift Completed (Checkout Pending)';
        }
      }

      final end = DateTime.parse(checkOutRaw.toString());
      final diff = end.difference(start);
      final hours = diff.inHours;
      final mins = diff.inMinutes % 60;
      if (hours > 0) {
        return '$hours hrs $mins mins';
      } else {
        return '$mins mins';
      }
    } catch (_) {
      return '--';
    }
  }

  String _formatDateFullStr(dynamic rawDate) {
    if (rawDate != null &&
        rawDate.toString().isNotEmpty &&
        rawDate.toString() != 'null') {
      try {
        final dt = DateTime.parse(rawDate.toString());
        return DateFormat('EEEE, d MMMM yyyy').format(dt.toLocal());
      } catch (_) {}
    }
    return DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
  }

  void _showEmployeeAttendanceDetailsModal(Map<String, dynamic> item) {
    final empName = item['name'] ?? 'Employee';
    final empSub = item['email'] ?? '';
    final statusStr = item['status'] ?? 'Absent';
    final checkInRaw = item['checkIn'];
    final checkOutRaw = item['checkOut'];

    final (statusBg, statusFg) = switch (statusStr.toLowerCase()) {
      'present' => (const Color(0xFFDCFCE7), const Color(0xFF10B981)),
      'on leave' ||
      'leave' => (const Color(0xFFFEF3C7), const Color(0xFFF59E0B)),
      _ => (const Color(0xFFFEE2E2), const Color(0xFFEF4444)),
    };

    final inTimeFormatted = _formatTimeStr(checkInRaw);
    final outTimeFormatted = _formatTimeStr(checkOutRaw);
    final durationStr = _calculateDurationStr(checkInRaw, checkOutRaw);
    final fullDateStr = _formatDateFullStr(checkInRaw);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: context.isDark ? 0.3 : 0.1,
                ),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle Bar
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

              // Header Bar with Close Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attendance Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.txtPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: context.txtMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Employee Profile Section
              Row(
                children: [
                  _buildAvatarWidget(item['avatar'], empName, 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          empName,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: context.txtPrimary,
                          ),
                        ),
                        if (empSub.isNotEmpty)
                          Text(
                            empSub,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.txtMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      statusStr,
                      style: TextStyle(
                        color: statusFg,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Date Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      fullDateStr,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (statusStr.toLowerCase().contains('leave')) ...[
                // Leave Type & Dates Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.event_available_rounded,
                            size: 18,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item['note'] ??
                                item['raw']?['leaveType'] ??
                                'Approved Leave',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Status: On Leave Today',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.txtPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Reason Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.cardLightBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.borderCol),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reason for Leave',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.txtMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (item['raw']?['reason']?.toString().isNotEmpty == true)
                            ? item['raw']['reason'].toString()
                            : 'Leave approved by administrator',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.txtPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Details Grid (Check In, Check Out)
                Row(
                  children: [
                    // Check In Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.login_rounded,
                                  size: 16,
                                  color: Color(0xFF10B981),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Check In',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              inTimeFormatted,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: context.txtPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Check Out Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color:
                              (checkOutRaw != null &&
                                  checkOutRaw.toString().isNotEmpty &&
                                  checkOutRaw.toString() != 'null')
                              ? const Color(0xFF6366F1).withValues(alpha: 0.08)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                (checkOutRaw != null &&
                                    checkOutRaw.toString().isNotEmpty &&
                                    checkOutRaw.toString() != 'null')
                                ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                                : const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.logout_rounded,
                                  size: 16,
                                  color:
                                      (checkOutRaw != null &&
                                          checkOutRaw.toString().isNotEmpty &&
                                          checkOutRaw.toString() != 'null')
                                      ? const Color(0xFF6366F1)
                                      : const Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Check Out',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        (checkOutRaw != null &&
                                            checkOutRaw.toString().isNotEmpty &&
                                            checkOutRaw.toString() != 'null')
                                        ? const Color(0xFF6366F1)
                                        : const Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              (checkOutRaw != null &&
                                      checkOutRaw.toString().isNotEmpty &&
                                      checkOutRaw.toString() != 'null')
                                  ? outTimeFormatted
                                  : 'Not Marked Yet',
                              style: TextStyle(
                                fontSize:
                                    (checkOutRaw != null &&
                                        checkOutRaw.toString().isNotEmpty &&
                                        checkOutRaw.toString() != 'null')
                                    ? 17
                                    : 13,
                                fontWeight: FontWeight.w800,
                                color:
                                    (checkOutRaw != null &&
                                        checkOutRaw.toString().isNotEmpty &&
                                        checkOutRaw.toString() != 'null')
                                    ? context.txtPrimary
                                    : const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Duration Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.cardLightBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.borderCol),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF59E0B,
                          ).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.timer_rounded,
                          size: 18,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Working Hours',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.txtMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            durationStr,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: context.txtPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdminModalChip({
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

  Widget _buildWelcomeBanner({required String authName}) {
    final auth = ref.watch(authProvider);
    final user = auth.user;

    // Current Date calculation dynamically
    final todayDate = DateFormat('d MMM yyyy').format(DateTime.now());

    final roleStr = (user?['role'] ?? auth.role ?? 'Admin').toString();
    final roleTitle = roleStr.toLowerCase() == 'admin'
        ? 'Super Admin'
        : roleStr;
    final statusText =
        (user?['status'] ?? 'Active').toString().toUpperCase() == 'INACTIVE'
        ? 'Inactive'
        : 'Active User';

    final isDark = context.isDark;

    return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: context.borderCol.withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // 1. Right-side Fluid Wave Decorative Background
                Positioned(
                  right: -15,
                  top: -15,
                  bottom: -15,
                  width: 180,
                  child: CustomPaint(
                    painter: _BannerWavePainter(isDark: isDark),
                  ),
                ),

                // Soft floating background circles
                Positioned(
                  right: 140,
                  top: 24,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF818CF8).withValues(alpha: 0.3),
                    ),
                  ),
                ),
                Positioned(
                  right: 130,
                  bottom: 30,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                    ),
                  ),
                ),

                // 2. Main Content Container (Compact Padding)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Left Greeting Info + Right Avatar & View Profile
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Greeting Column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF3B82F6,
                                        ).withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Text(
                                        '👋',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Welcome back,',
                                      style: TextStyle(
                                        color: context.txtSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        authName.split(' ').first,
                                        style: TextStyle(
                                          color: context.txtPrimary,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                          height: 1.1,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Text(
                                      '👋',
                                      style: TextStyle(fontSize: 19),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),

                                Text(
                                  "Here's what's happening today.",
                                  style: TextStyle(
                                    color: context.txtMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Blue accent underline line
                                Container(
                                  width: 28,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 10),

                          // Right Column: Compact Profile Avatar with Badge + View Profile Button
                          Column(
                            children: [
                              GestureDetector(
                                onTap: () => showPhotoPreview(
                                  context,
                                  avatarOrUser: user,
                                  title: authName,
                                  subtitle: roleTitle.toUpperCase(),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Outer translucent glow ring
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(
                                          0xFF6366F1,
                                        ).withValues(alpha: 0.12),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF818CF8,
                                          ).withValues(alpha: 0.35),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    // Inner white/card border ring around avatar
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF1E293B)
                                              : Colors.white,
                                          width: 2.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.12,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: _buildAvatarWidget(
                                        user,
                                        authName,
                                        29,
                                      ),
                                    ),
                                    // Green Verified Checkmark Badge
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isDark
                                                ? const Color(0xFF1E293B)
                                                : Colors.white,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF10B981,
                                              ).withValues(alpha: 0.4),
                                              blurRadius: 5,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Compact View Profile Pill Button
                              InkWell(
                                onTap: () => context.push('/settings'),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF2563EB),
                                        Color(0xFF1D4ED8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF2563EB,
                                        ).withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.person_rounded,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'View Profile',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(width: 3),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 11,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Bottom 3 Info Mini Cards Row (Member Since, Active User, Super Admin / System Role)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            // Card 1: Today's Current Date
                            _buildBannerMiniCard(
                              icon: Icons.calendar_today_rounded,
                              iconColor: const Color(0xFF6366F1),
                              iconBgColor: const Color(0xFFEEF2FF),
                              title: todayDate,
                              subtitle: 'Today\'s Date',
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),

                            // Card 2: Status
                            _buildBannerMiniCard(
                              icon: Icons.verified_user_rounded,
                              iconColor: const Color(0xFF10B981),
                              iconBgColor: const Color(0xFFECFDF5),
                              title: statusText,
                              subtitle: 'Status',
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),

                            // Card 3: System Role (Replaced Premium)
                            _buildBannerMiniCard(
                              icon: Icons.admin_panel_settings_rounded,
                              iconColor: const Color(0xFF8B5CF6),
                              iconBgColor: const Color(0xFFF3E8FF),
                              title: roleTitle,
                              subtitle: 'System Role',
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 350))
        .scale(
          begin: const Offset(0.97, 0.97),
          end: const Offset(1.0, 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildBannerMiniCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(minWidth: 95),
      decoration: BoxDecoration(
        color: isDark ? context.cardLightBg : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? context.borderCol : const Color(0xFFF1F5F9),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? iconColor.withValues(alpha: 0.15) : iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.txtPrimary,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: context.txtMuted,
            ),
          ),
        ],
      ),
    );
  }

  // --- Overview Stat Card Component ---
  
  Widget _buildDynamicOverviewCardItem({
    required DashboardCardConfig card,
    required String totalEmp,
    required String presentCount,
    required String leaveCount,
    required String absentCount,
  }) {
    Color cardColor = card.parsedColor;
    final cardTitle = card.title.isNotEmpty ? card.title : 'Overview Box';
    
    final rawType = card.dataType.toLowerCase().trim();
    final rawId = card.id.toLowerCase().trim();
    final titleLower = cardTitle.toLowerCase().trim();

    String cardValue = '0';
    IconData cardIcon = card.parsedIcon;
    VoidCallback? onTapAction;

    // 1. Total Employees
    if (rawType == 'total_employees' ||
        rawId == 'total_employees' ||
        rawType == 'employees' ||
        rawId == 'employees' ||
        rawId.contains('employee') ||
        titleLower.contains('total employee') ||
        titleLower.contains('total staff') ||
        titleLower.contains('employee count') ||
        titleLower == 'employees' ||
        titleLower == 'staff' ||
        titleLower == 'workforce') {
      cardValue = totalEmp;
      cardIcon = Icons.groups_rounded;
      if (cardColor == const Color(0xFF6366F1)) {
        cardColor = const Color(0xFF6366F1);
      }
      onTapAction = () => setState(() => _selectedIndex = 1);
    }
    // 2. Present Today
    else if (rawType == 'present_today' ||
        rawId == 'present_today' ||
        rawType == 'present' ||
        rawId == 'present' ||
        rawId.contains('present') ||
        titleLower.contains('present today') ||
        titleLower == 'present' ||
        titleLower.contains('present staff') ||
        titleLower.contains('present count')) {
      cardValue = presentCount;
      cardIcon = Icons.check_circle_rounded;
      onTapAction = () => _showAttendanceModal(
        context,
        ref,
        title: cardTitle,
        statusType: 'present',
      );
    }
    // 3. On Leave Today
    else if (rawType == 'on_leave_today' ||
        rawId == 'on_leave_today' ||
        rawType == 'leave' ||
        rawId == 'leave' ||
        rawType == 'on_leave' ||
        rawId.contains('leave') ||
        titleLower.contains('leave today') ||
        titleLower.contains('on leave') ||
        titleLower == 'leave' ||
        titleLower == 'leaves') {
      cardValue = leaveCount;
      cardIcon = Icons.calendar_month_rounded;
      onTapAction = () => _showAttendanceModal(
        context,
        ref,
        title: cardTitle,
        statusType: 'leave',
      );
    }
    // 4. Absent Today
    else if (rawType == 'absent_today' ||
        rawId == 'absent_today' ||
        rawType == 'absent' ||
        rawId == 'absent' ||
        rawId.contains('absent') ||
        titleLower.contains('absent today') ||
        titleLower.contains('absent') ||
        titleLower == 'absent') {
      cardValue = absentCount;
      cardIcon = Icons.cancel_rounded;
      onTapAction = () => _showAttendanceModal(
        context,
        ref,
        title: cardTitle,
        statusType: 'absent',
      );
    }
    // 5. Projects
    else if (rawType == 'total_projects' ||
        rawId == 'total_projects' ||
        rawType == 'projects' ||
        rawId == 'projects' ||
        rawId.contains('project') ||
        titleLower.contains('project')) {
      final statsVal = ref.watch(attendanceProvider).stats?['totalProjects']?.toString();
      cardValue = (statsVal != null && statsVal.isNotEmpty)
          ? statsVal
          : ((card.customValue != null && card.customValue!.isNotEmpty) ? card.customValue! : '12');
      cardIcon = Icons.folder_rounded;
      onTapAction = () => context.push('/admin/projects');
    }
    // 6. Shifts
    else if (rawType == 'total_shifts' ||
        rawId == 'total_shifts' ||
        rawType == 'shifts' ||
        rawId == 'shifts' ||
        rawId.contains('shift') ||
        titleLower.contains('shift')) {
      final statsVal = ref.watch(attendanceProvider).stats?['totalShifts']?.toString();
      cardValue = (statsVal != null && statsVal.isNotEmpty)
          ? statsVal
          : ((card.customValue != null && card.customValue!.isNotEmpty) ? card.customValue! : '4');
      cardIcon = Icons.schedule_rounded;
      onTapAction = () => context.push('/admin/shifts');
    }
    // 7. Holidays
    else if (rawType == 'total_holidays' ||
        rawId == 'total_holidays' ||
        rawType == 'holidays' ||
        rawId == 'holidays' ||
        rawId.contains('holiday') ||
        titleLower.contains('holiday')) {
      final statsVal = ref.watch(attendanceProvider).stats?['totalHolidays']?.toString();
      cardValue = (statsVal != null && statsVal.isNotEmpty)
          ? statsVal
          : ((card.customValue != null && card.customValue!.isNotEmpty) ? card.customValue! : '2');
      cardIcon = Icons.beach_access_rounded;
      onTapAction = () => context.push('/admin/holidays');
    }
    // 8. Salary & Payroll
    else if (rawType == 'salary' ||
        rawId == 'salary' ||
        rawType == 'payroll' ||
        rawId == 'payroll' ||
        rawId.contains('salary') ||
        titleLower.contains('salary') ||
        titleLower.contains('payroll')) {
      final statsVal = ref.watch(attendanceProvider).stats?['salary']?.toString();
      cardValue = (statsVal != null && statsVal.isNotEmpty)
          ? statsVal
          : ((card.customValue != null && card.customValue!.isNotEmpty) ? card.customValue! : '₹4.8L');
      cardIcon = Icons.payments_rounded;
      onTapAction = () => context.push('/admin/salary');
    }
    // 9. Tasks
    else if (rawType == 'pending_tasks' ||
        rawId == 'pending_tasks' ||
        rawType == 'tasks' ||
        rawId == 'tasks' ||
        rawId.contains('task') ||
        titleLower.contains('task')) {
      final statsVal = ref.watch(attendanceProvider).stats?['pendingTasks']?.toString();
      cardValue = (statsVal != null && statsVal.isNotEmpty)
          ? statsVal
          : ((card.customValue != null && card.customValue!.isNotEmpty) ? card.customValue! : '9');
      cardIcon = Icons.task_alt_rounded;
      onTapAction = () => context.push('/admin/tasks');
    }
    // 10. Pending Leaves
    else if (rawType == 'pending_leaves' ||
        rawId == 'pending_leaves' ||
        titleLower.contains('pending leave')) {
      cardValue = leaveCount.isNotEmpty ? leaveCount : '0';
      cardIcon = Icons.pending_actions_rounded;
      onTapAction = () => _showAttendanceModal(
        context,
        ref,
        title: cardTitle,
        statusType: 'leave',
      );
    }
    // 11. Reports
    else if (rawType == 'reports' ||
        rawId == 'reports' ||
        titleLower.contains('report')) {
      final statsVal = ref.watch(attendanceProvider).stats?['reports']?.toString();
      cardValue = (statsVal != null && statsVal.isNotEmpty)
          ? statsVal
          : ((card.customValue != null && card.customValue!.isNotEmpty) ? card.customValue! : '98%');
      cardIcon = Icons.analytics_rounded;
      onTapAction = () => context.push('/admin/reports');
    }
    // 12. Work Hours
    else if (rawType == 'workhours' ||
        rawId == 'workhours' ||
        titleLower.contains('work hour') ||
        titleLower.contains('workhour')) {
      final statsVal = ref.watch(attendanceProvider).stats?['workhours']?.toString();
      cardValue = (statsVal != null && statsVal.isNotEmpty)
          ? statsVal
          : ((card.customValue != null && card.customValue!.isNotEmpty) ? card.customValue! : '8.5h');
      cardIcon = Icons.timer_rounded;
      onTapAction = () => context.push('/admin/workhours');
    }
    // 13. AI Assistant
    else if (rawType == 'ai_insights' ||
        rawId == 'ai_insights' ||
        titleLower.contains('ai')) {
      final statsVal = ref.watch(attendanceProvider).stats?['ai']?.toString();
      cardValue = (statsVal != null && statsVal.isNotEmpty)
          ? statsVal
          : ((card.customValue != null && card.customValue!.isNotEmpty) ? card.customValue! : 'AI On');
      cardIcon = Icons.psychology_rounded;
      onTapAction = () => context.push('/admin/ai-insights');
    }
    // 14. Custom or fallback
    else {
      cardValue = (card.customValue != null && card.customValue!.isNotEmpty)
          ? card.customValue!
          : '0';
      cardIcon = card.parsedIcon;
      if (card.route != null && card.route!.isNotEmpty) {
        onTapAction = () => context.push(card.route!);
      }
    }

    // If card has an explicitly specified icon other than default, use it
    if (card.icon != null &&
        card.icon!.isNotEmpty &&
        card.parsedIcon != Icons.dashboard_customize_rounded) {
      cardIcon = card.parsedIcon;
    }

    final cardBgColor = cardColor.withValues(alpha: 0.12);

    return _buildOverviewCard(
      title: cardTitle,
      value: cardValue,
      icon: cardIcon,
      color: cardColor,
      bgColor: cardBgColor,
      onTap: onTapAction,
    );
  }

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
          border: Border.all(color: context.borderCol, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: context.isDark ? 0.1 : 0.04,
              ),
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
                Icon(
                  Icons.event_available_rounded,
                  size: 36,
                  color: context.txtMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 10),
                Text(
                  'No pending leaves',
                  style: TextStyle(color: context.txtMuted, fontSize: 14),
                ),
              ],
            ),
          )
        else
          ...pendingLeaves
              .take(3)
              .map((leave) => _buildPendingLeaveCard(leave)),
      ],
    );
  }

  Widget _buildAvatarWidget(
    dynamic avatarOrUser,
    String fallbackText,
    double radius,
  ) {
    return AppAvatar(
      avatarOrUser: avatarOrUser,
      fallbackText: fallbackText,
      radius: radius,
    );
  }

  // --- Modern Sleek Leave Card Component ---
  Widget _buildPendingLeaveCard(dynamic leave) {
    if (leave is! Map) return const SizedBox.shrink();

    final allEmps = ref.read(employeeProvider).employees;
    final (employeeName, empAvatar) = _extractLeaveEmployeeInfo(leave, allEmps);

    final leaveType = (leave['leaveType'] ?? leave['type'] ?? 'Leave').toString();
    final leaveId = leave['_id']?.toString() ?? leave['id']?.toString() ?? '';
    final reason = (leave['reason'] ?? '').toString().trim();
    final statusStr = (leave['status'] ?? 'Pending').toString();
    final statusLower = statusStr.toLowerCase();
    final isPending = statusLower == 'pending';
    final isApproved = statusLower == 'approved';

    // Format dates from ISO strings
    String dateStr;
    int dayCount = 1;
    final startRaw = leave['startDate'] ?? leave['from'] ?? leave['fromDate'] ?? leave['start_date'];
    final endRaw = leave['endDate'] ?? leave['to'] ?? leave['toDate'] ?? leave['end_date'];
    try {
      final start = DateTime.parse(startRaw.toString());
      final end = DateTime.parse(endRaw.toString());
      final fmt = DateFormat('d MMM');
      dateStr = (start.day == end.day && start.month == end.month && start.year == end.year)
          ? fmt.format(start)
          : '${fmt.format(start)} - ${fmt.format(end)}';
      dayCount = end.difference(start).inDays + 1;
      if (dayCount < 1) dayCount = 1;
    } catch (_) {
      dateStr = startRaw?.toString() ?? 'N/A';
    }

    final (badgeBg, badgeFg, badgeBorder, badgeIcon, displayStatus) = isApproved
        ? (
            const Color(0xFF10B981).withValues(alpha: 0.12),
            const Color(0xFF10B981),
            const Color(0xFF10B981).withValues(alpha: 0.3),
            Icons.check_circle_rounded,
            'Approved',
          )
        : isPending
            ? (
                const Color(0xFFF59E0B).withValues(alpha: 0.12),
                const Color(0xFFF59E0B),
                const Color(0xFFF59E0B).withValues(alpha: 0.3),
                Icons.schedule_rounded,
                'Pending',
              )
            : (
                const Color(0xFFEF4444).withValues(alpha: 0.12),
                const Color(0xFFEF4444),
                const Color(0xFFEF4444).withValues(alpha: 0.3),
                Icons.cancel_rounded,
                statusStr.isNotEmpty ? statusStr : 'Rejected',
              );

    return InkWell(
      onTap: () => _showLeaveDetailsBottomSheet(leave, employeeName, empAvatar, dateStr, dayCount),
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Employee Name & Date + Top-Right Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAvatarWidget(empAvatar, employeeName, 20),
                const SizedBox(width: 12),
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
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '$leaveType • $dateStr',
                              style: TextStyle(
                                color: context.txtMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              dayCount == 1 ? '1d' : '${dayCount}d',
                              style: const TextStyle(
                                color: Color(0xFF6366F1),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Sleek Top-Right Status Pill Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeBorder, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 13, color: badgeFg),
                      const SizedBox(width: 4),
                      Text(
                        displayStatus,
                        style: TextStyle(
                          color: badgeFg,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Optional Reason Preview Box
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: context.isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: context.borderCol.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      size: 14,
                      color: context.txtMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        reason,
                        style: TextStyle(
                          color: context.txtSecondary,
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action Buttons Row ONLY for PENDING leaves
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _approveLeave(leaveId, 'Rejected'),
                      icon: const Icon(Icons.close_rounded, size: 15),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: BorderSide(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveLeave(leaveId, 'Approved'),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showLeaveDetailsBottomSheet(
    dynamic leave,
    String employeeName,
    String? empAvatar,
    String dateStr,
    int dayCount,
  ) {
    if (leave is! Map) return;
    final leaveType = (leave['leaveType'] ?? leave['type'] ?? 'Leave').toString();
    final reason = (leave['reason'] ?? 'No reason provided').toString().trim();
    final statusStr = (leave['status'] ?? 'Pending').toString();
    final leaveId = leave['_id']?.toString() ?? leave['id']?.toString() ?? '';
    final isPending = statusStr.toLowerCase() == 'pending';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: context.isDark ? 0.3 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
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
              const SizedBox(height: 18),
              Row(
                children: [
                  _buildAvatarWidget(empAvatar, employeeName, 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employeeName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.txtPrimary,
                          ),
                        ),
                        Text(
                          '$leaveType Application',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.txtMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: context.txtMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.cardLightBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderCol),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Duration:', style: TextStyle(color: context.txtMuted, fontSize: 13)),
                        Text('$dateStr ($dayCount ${dayCount == 1 ? "Day" : "Days"})',
                            style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Status:', style: TextStyle(color: context.txtMuted, fontSize: 13)),
                        Text(statusStr,
                            style: TextStyle(
                              color: statusStr.toLowerCase() == 'approved'
                                  ? const Color(0xFF10B981)
                                  : statusStr.toLowerCase() == 'pending'
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFFEF4444),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('Reason for Leave:',
                  style: TextStyle(color: context.txtMuted, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.borderCol),
                ),
                child: Text(
                  reason,
                  style: TextStyle(color: context.txtPrimary, fontSize: 13.5, height: 1.4),
                ),
              ),
              if (isPending) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _approveLeave(leaveId, 'Rejected');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Reject Leave', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _approveLeave(leaveId, 'Approved');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Approve Leave', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
            ],
          ),
        );
      },
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
              border: Border.all(
                color: color.withValues(alpha: 0.25),
                width: 1,
              ),
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
          backgroundColor: status == 'Approved'
              ? const Color(0xFF10B981)
              : const Color(0xFFEF4444),
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
  Widget _buildAdminDrawer(
    BuildContext context,
    WidgetRef ref,
    AuthState auth,
  ) {
    final rawUser = auth.user;
    final Map<String, dynamic>? userMap =
        rawUser is Map ? Map<String, dynamic>.from(rawUser as Map) : null;
    final userName = userMap?['name']?.toString() ??
        userMap?['fullName']?.toString() ??
        'Admin User';
    final userEmail = userMap?['email']?.toString() ?? 'admin@ams.com';

    return Drawer(
      backgroundColor: context.drawerBg,
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 20,
                20,
                20,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1E1B4B),
                    Color(0xFF312E81),
                    Color(0xFF4338CA),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatarWidget(rawUser, userName, 30),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.dashboard_rounded,
                    color: Color(0xFF6366F1),
                  ),
                  title: Text(
                    'Dashboard',
                    style: TextStyle(
                      color: context.txtPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 0);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.chat_rounded,
                    color: Color(0xFF6366F1),
                  ),
                  title: Text(
                    'Messages',
                    style: TextStyle(
                      color: context.txtPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/chat');
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Color(0xFF10B981),
                  ),
                  title: Text(
                    'Add New Employee',
                    style: TextStyle(
                      color: context.txtPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Onboard staff & assign permissions',
                    style: TextStyle(color: context.txtMuted, fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddEmployeeModal(context);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.people_alt_rounded,
                    color: Color(0xFF3B82F6),
                  ),
                  title: Text(
                    'Employee Directory',
                    style: TextStyle(
                      color: context.txtPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Manage employees, edit roles',
                    style: TextStyle(color: context.txtMuted, fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 1);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.face_retouching_natural_rounded,
                    color: Color(0xFF06B6D4),
                  ),
                  title: Text(
                    'Face Lock Attendance',
                    style: TextStyle(
                      color: context.txtPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'View employee face photos & scans',
                    style: TextStyle(color: context.txtMuted, fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/admin/face-attendance');
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.access_time_filled_rounded,
                    color: Color(0xFF8B5CF6),
                  ),
                  title: Text(
                    'Admin Mark Attendance',
                    style: TextStyle(
                      color: context.txtPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Manual attendance entry',
                    style: TextStyle(color: context.txtMuted, fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showAdminMarkAttendanceModal(context);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.event_available_rounded,
                    color: Color(0xFFF59E0B),
                  ),
                  title: Text(
                    'Leave Approvals',
                    style: TextStyle(
                      color: context.txtPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Approve or reject leave requests',
                    style: TextStyle(color: context.txtMuted, fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 2);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.insert_chart_rounded,
                    color: Color(0xFF06B6D4),
                  ),
                  title: Text(
                    'Reports & Analytics',
                    style: TextStyle(
                      color: context.txtPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Attendance metrics & statistics',
                    style: TextStyle(color: context.txtMuted, fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/admin/analytics');
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.payments_rounded,
                    color: Color(0xFF10B981),
                  ),
                  title: Text(
                    'Salary & Payroll',
                    style: TextStyle(
                      color: context.txtPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Calculate and manage monthly salary',
                    style: TextStyle(color: context.txtMuted, fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/admin/salary');
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.assignment_rounded,
                    color: Color(0xFF6366F1),
                  ),
                  title: Text(
                    'Projects & Tasks',
                    style: TextStyle(
                      color: context.txtPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Track project deadlines and team progress',
                    style: TextStyle(color: context.txtMuted, fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/admin/projects');
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.holiday_village_rounded,
                    color: Color(0xFFEC4899),
                  ),
                  title: Text(
                    'Holidays Calendar',
                    style: TextStyle(
                      color: context.txtPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'View upcoming public and company holidays',
                    style: TextStyle(color: context.txtMuted, fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/admin/holidays');
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.notifications_active_rounded,
                    color: Color(0xFFF59E0B),
                  ),
                  title: Text(
                    'Notifications Center',
                    style: TextStyle(
                      color: context.txtPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/admin/notifications');
                  },
                ),
                Divider(color: context.dividerCol),
                ListTile(
                  leading: const Icon(
                    Icons.badge_rounded,
                    color: Color(0xFF64748B),
                  ),
                  title: Text(
                    'Switch to Employee View',
                    style: TextStyle(color: context.txtPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/employee/dashboard');
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.settings_rounded,
                    color: Color(0xFF64748B),
                  ),
                  title: Text(
                    'Settings & Biometrics',
                    style: TextStyle(color: context.txtPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/settings');
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFEF4444),
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/welcome');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text(
                  'Add Employee',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _showAddEmployeeModal(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : state.employees.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 48,
                        color: context.txtMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No employees found',
                        style: TextStyle(color: context.txtMuted, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Employee'),
                        onPressed: () => _showAddEmployeeModal(context),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(employeeProvider.notifier).loadEmployees(),
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
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
              _buildAvatarWidget(emp, name, 23),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: role == 'ADMIN'
                                ? const Color(
                                    0xFFEC4899,
                                  ).withValues(alpha: 0.15)
                                : AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            role,
                            style: TextStyle(
                              color: role == 'ADMIN'
                                  ? const Color(0xFFEC4899)
                                  : AppColors.primary,
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
                      style: TextStyle(
                        color: context.txtSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
                icon: const Icon(Icons.access_time_rounded, size: 16),
                label: const Text(
                  'Mark Attendance',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: () => _showAdminMarkAttendanceModal(
                  context,
                  preselectedEmpId: empId,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Color(0xFF6366F1),
                ),
                tooltip: 'Edit Employee',
                onPressed: () => _showEditEmployeeModal(context, emp),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Color(0xFFEF4444),
                ),
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
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
                              color: const Color(
                                0xFF6366F1,
                              ).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: Color(0xFF6366F1),
                              size: 24,
                            ),
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter employee name'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: context.txtPrimary),
                        decoration: InputDecoration(
                          labelText: 'Email Address *',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Enter valid email'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordCtrl,
                        obscureText: true,
                        style: TextStyle(color: context.txtPrimary),
                        decoration: InputDecoration(
                          labelText: 'Password *',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 4)
                            ? 'Password must be at least 4 chars'
                            : null,
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
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items:
                                  [
                                        'IT',
                                        'HR',
                                        'Sales',
                                        'Marketing',
                                        'Finance',
                                        'Engineering',
                                        'Operations',
                                      ]
                                      .map(
                                        (d) => DropdownMenuItem(
                                          value: d,
                                          child: Text(d),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (val) =>
                                  setModalState(() => selectedDept = val!),
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
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'employee',
                                  child: Text('Employee'),
                                ),
                                DropdownMenuItem(
                                  value: 'admin',
                                  child: Text('Admin (All Access)'),
                                ),
                              ],
                              onChanged: (val) =>
                                  setModalState(() => selectedRole = val!),
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.check_circle_rounded),
                          label: const Text(
                            'Add Employee',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () async {
                            if (formKey.currentState?.validate() ?? false) {
                              Navigator.pop(ctx);
                              final ok = await ref
                                  .read(employeeProvider.notifier)
                                  .addEmployee({
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
                                    content: Text(
                                      'Employee ${nameCtrl.text} added successfully!',
                                    ),
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
    final emailCtrl = TextEditingController(
      text: emp['email']?.toString() ?? '',
    );
    final phoneCtrl = TextEditingController(
      text: emp['phone']?.toString() ?? '',
    );
    final designationCtrl = TextEditingController(
      text: emp['designation']?.toString() ?? '',
    );
    String selectedDept =
        (emp['department'] != null && emp['department'].toString().isNotEmpty)
        ? emp['department'].toString()
        : 'IT';
    if (![
      'IT',
      'HR',
      'Sales',
      'Marketing',
      'Finance',
      'Engineering',
      'Operations',
    ].contains(selectedDept)) {
      selectedDept = 'IT';
    }
    String selectedRole = (emp['role']?.toString().toLowerCase() == 'admin')
        ? 'admin'
        : 'employee';

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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
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
                          child: const Icon(
                            Icons.edit_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      style: TextStyle(color: context.txtPrimary),
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items:
                                [
                                      'IT',
                                      'HR',
                                      'Sales',
                                      'Marketing',
                                      'Finance',
                                      'Engineering',
                                      'Operations',
                                    ]
                                    .map(
                                      (d) => DropdownMenuItem(
                                        value: d,
                                        child: Text(d),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (val) =>
                                setModalState(() => selectedDept = val!),
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
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'employee',
                                child: Text('Employee'),
                              ),
                              DropdownMenuItem(
                                value: 'admin',
                                child: Text('Admin'),
                              ),
                            ],
                            onChanged: (val) =>
                                setModalState(() => selectedRole = val!),
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      style: TextStyle(color: context.txtPrimary),
                      decoration: InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.save_rounded),
                        label: const Text(
                          'Update Employee',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final ok = await ref
                              .read(employeeProvider.notifier)
                              .updateEmployee(empId, {
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFEF4444),
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                'Delete Employee',
                style: TextStyle(
                  color: context.txtPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await ref
                    .read(employeeProvider.notifier)
                    .deleteEmployee(empId);
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

  void _showAdminMarkAttendanceModal(
    BuildContext context, {
    String? preselectedEmpId,
  }) {
    final employees = ref.read(employeeProvider).employees;
    if (employees.isEmpty) {
      ref.read(employeeProvider.notifier).loadEmployees();
    }
    String selectedEmpId =
        preselectedEmpId ??
        (employees.isNotEmpty
            ? (employees.first['_id']?.toString() ??
                  employees.first['id']?.toString() ??
                  '')
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
              selectedEmpId =
                  empList.first['_id']?.toString() ??
                  empList.first['id']?.toString() ??
                  '';
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
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
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.access_time_filled_rounded,
                            color: Color(0xFF10B981),
                            size: 24,
                          ),
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
                      initialValue: selectedEmpId.isNotEmpty
                          ? selectedEmpId
                          : null,
                      dropdownColor: context.cardBg,
                      style: TextStyle(color: context.txtPrimary),
                      decoration: InputDecoration(
                        labelText: 'Select Employee',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.person_search_rounded),
                      ),
                      items: empList.map<DropdownMenuItem<String>>((e) {
                        final id =
                            e['_id']?.toString() ?? e['id']?.toString() ?? '';
                        final name = e['name'] ?? 'Employee';
                        final dept = e['department'] ?? '';
                        return DropdownMenuItem(
                          value: id,
                          child: Text('$name ($dept)'),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setModalState(() => selectedEmpId = val ?? ''),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Attendance Status',
                      style: TextStyle(
                        color: context.txtPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Present', 'Late', 'Half Day', 'Absent'].map((
                        st,
                      ) {
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
                          onSelected: (_) =>
                              setModalState(() => selectedStatus = st),
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text(
                          'Submit Attendance',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () async {
                          if (selectedEmpId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select an employee'),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          final ok = await ref
                              .read(attendanceProvider.notifier)
                              .adminMarkAttendance(
                                employeeId: selectedEmpId,
                                status: selectedStatus,
                                notes: notesCtrl.text.trim(),
                              );
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Attendance marked as $selectedStatus',
                                ),
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

  // --- Leaves Tab (Leave Status) ---
  Widget _buildLeaveApprovalTab() {
    final attendance = ref.watch(attendanceProvider);
    final allLeavesList = attendance.allLeaves;

    final pendingCount = allLeavesList
        .where(
          (l) =>
              (l is Map &&
              (l['status'] ?? '').toString().toLowerCase() == 'pending'),
        )
        .length;
    final approvedCount = allLeavesList
        .where(
          (l) =>
              (l is Map &&
              (l['status'] ?? '').toString().toLowerCase() == 'approved'),
        )
        .length;
    final rejectedCount = allLeavesList.where((l) {
      if (l is! Map) return false;
      final st = (l['status'] ?? '').toString().toLowerCase();
      return st == 'rejected' || st == 'cancelled';
    }).length;

    final filteredLeaves = allLeavesList.where((l) {
      if (l is! Map) return false;
      final st = (l['status'] ?? '').toString().toLowerCase();
      if (_leaveFilter == 'Approved') return st == 'approved';
      if (_leaveFilter == 'Pending') return st == 'pending';
      if (_leaveFilter == 'Rejected') {
        return st == 'rejected' || st == 'cancelled';
      }
      return true;
    }).toList();

    final filterOptions = [
      {
        'label': 'All',
        'count': allLeavesList.length,
        'color': const Color(0xFF6366F1),
      },
      {
        'label': 'Approved',
        'count': approvedCount,
        'color': const Color(0xFF10B981),
      },
      {
        'label': 'Pending',
        'count': pendingCount,
        'color': const Color(0xFFF59E0B),
      },
      {
        'label': 'Rejected',
        'count': rejectedCount,
        'color': const Color(0xFFEF4444),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Text(
                'Leave Status',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.txtPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${filteredLeaves.length} items',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Interactive Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSel ? color : context.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel ? color : context.borderCol,
                        width: isSel ? 1.5 : 1,
                      ),
                      boxShadow: isSel
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: isSel ? Colors.white : context.txtPrimary,
                            fontWeight: isSel
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSel
                                ? Colors.white.withValues(alpha: 0.25)
                                : color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: isSel ? Colors.white : color,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
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
        const SizedBox(height: 8),

        // List / Empty View
        Expanded(
          child: attendance.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : filteredLeaves.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _leaveFilter == 'Approved'
                            ? Icons.check_circle_outline_rounded
                            : _leaveFilter == 'Pending'
                            ? Icons.pending_actions_rounded
                            : Icons.event_busy_rounded,
                        size: 48,
                        color: context.txtMuted.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _leaveFilter == 'Approved'
                            ? 'No approved leaves'
                            : _leaveFilter == 'Pending'
                            ? 'No pending leave requests'
                            : _leaveFilter == 'Rejected'
                            ? 'No rejected leaves'
                            : 'No leave records found',
                        style: TextStyle(
                          color: context.txtMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () =>
                      ref.read(attendanceProvider.notifier).loadAllLeaves(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    itemCount: filteredLeaves.length,
                    itemBuilder: (ctx, i) =>
                        _buildPendingLeaveCard(filteredLeaves[i]),
                  ),
                ),
        ),
      ],
    );
  }


  // --- More Tab ---
  Widget _buildMoreTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildMoreItem(
            Icons.holiday_village_outlined,
            'Holidays',
            () => context.go('/admin/holidays'),
          ),
          _buildMoreItem(
            Icons.analytics_outlined,
            'Analytics',
            () => context.go('/admin/analytics'),
          ),
          _buildMoreItem(
            Icons.folder_outlined,
            'Projects',
            () => context.go('/admin/projects'),
          ),
          _buildMoreItem(
            Icons.payment_outlined,
            'Salary',
            () => context.go('/admin/salary'),
          ),
          _buildMoreItem(
            Icons.notifications_outlined,
            'Notifications',
            () => context.go('/admin/notifications'),
          ),
          // Theme Switch
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              tileColor: context.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: context.borderCol),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      (ref.watch(themeProvider) == ThemeMode.dark
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
                ref.watch(themeProvider) == ThemeMode.dark
                    ? 'Light Mode'
                    : 'Dark Mode',
                style: TextStyle(
                  color: context.txtPrimary,
                  fontWeight: FontWeight.w500,
                ),
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
          CustomLogoutButton(
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (mounted) context.go('/welcome');
            },
          ),
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
        title: Text(
          label,
          style: TextStyle(
            color: context.txtPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: context.txtMuted, size: 20),
        onTap: onTap,
      ),
    );
  }

  // --- Dynamic Bottom Navigation Bar (Configured via Website Dashboard Settings) ---
  Widget _buildBottomNav() {
    final activeNav = ref.watch(dashboardConfigProvider).enabledBottomNav;
    final safeIndex = _selectedIndex < activeNav.length ? _selectedIndex : 0;

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
        currentIndex: safeIndex,
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF6366F1),
        unselectedItemColor: context.txtMuted,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (i) {
          setState(() => _selectedIndex = i);
          if (i < activeNav.length) {
            final tabId = activeNav[i].id.toLowerCase();
            if (tabId == 'leaves' || tabId == 'pending_leaves') {
              ref.read(attendanceProvider.notifier).loadAllLeaves();
            }
          }
        },
        items: activeNav.map((item) {
          final icons = _getNavIcons(item.icon, item.id);
          return BottomNavigationBarItem(
            icon: Icon(icons.$1),
            activeIcon: Icon(icons.$2),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }

  (IconData, IconData) _getNavIcons(String iconType, String id) {
    switch (id.toLowerCase()) {
      case 'dashboard':
        return (Icons.home_outlined, Icons.home_rounded);
      case 'employees':
        return (Icons.people_outline_rounded, Icons.people_rounded);
      case 'leaves':
      case 'pending_leaves':
        return (Icons.business_center_outlined, Icons.business_center_rounded);
      case 'messages':
      case 'chat':
        return (Icons.chat_outlined, Icons.chat_rounded);
      case 'more':
        return (Icons.more_horiz_rounded, Icons.more_horiz_rounded);
      case 'projects':
        return (Icons.folder_outlined, Icons.folder_rounded);
      case 'shifts':
        return (Icons.schedule_outlined, Icons.schedule_rounded);
      case 'salary':
        return (Icons.payments_outlined, Icons.payments_rounded);
      case 'analytics':
        return (Icons.analytics_outlined, Icons.analytics_rounded);
      case 'holidays':
        return (Icons.beach_access_outlined, Icons.beach_access_rounded);
      case 'tasks':
        return (Icons.task_alt_outlined, Icons.task_alt_rounded);
      default:
        return (Icons.dashboard_outlined, Icons.dashboard_rounded);
    }
  }
}

class _BannerWavePainter extends CustomPainter {
  final bool isDark;

  _BannerWavePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Outer soft gradient wave
    final paint1 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: isDark
            ? [
                const Color(0xFF4F46E5).withValues(alpha: 0.25),
                const Color(0xFF6366F1).withValues(alpha: 0.15),
                const Color(0xFF3B82F6).withValues(alpha: 0.05),
              ]
            : [
                const Color(0xFF818CF8).withValues(alpha: 0.35),
                const Color(0xFF6366F1).withValues(alpha: 0.25),
                const Color(0xFF3B82F6).withValues(alpha: 0.1),
              ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    final path1 = Path();
    path1.moveTo(width * 0.2, 0);
    path1.quadraticBezierTo(
      width * 0.05,
      height * 0.4,
      width * 0.45,
      height * 0.7,
    );
    path1.quadraticBezierTo(width * 0.7, height * 0.9, width, height);
    path1.lineTo(width, 0);
    path1.close();
    canvas.drawPath(path1, paint1);

    // Inner vibrant gradient wave
    final paint2 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                const Color(0xFF6366F1).withValues(alpha: 0.35),
                const Color(0xFF3B82F6).withValues(alpha: 0.20),
              ]
            : [
                const Color(0xFF818CF8).withValues(alpha: 0.45),
                const Color(0xFF6366F1).withValues(alpha: 0.30),
              ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    final path2 = Path();
    path2.moveTo(width * 0.5, 0);
    path2.quadraticBezierTo(width * 0.35, height * 0.5, width * 0.6, height);
    path2.lineTo(width, height);
    path2.lineTo(width, 0);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Helper function to check if a leave application is APPROVED and active TODAY (Asia/Kolkata IST)
bool isLeaveActiveToday(dynamic leave, [DateTime? targetDate]) {
  if (leave is! Map) return false;

  // 1. Must be APPROVED (case-insensitive)
  final status = (leave['status'] ?? '').toString().trim().toLowerCase();
  if (status != 'approved') return false;

  // 2. Parse startDate & endDate
  final rawStart = leave['startDate'] ?? leave['start_date'] ?? leave['from'];
  final rawEnd = leave['endDate'] ?? leave['end_date'] ?? leave['to'];
  if (rawStart == null || rawEnd == null) return false;

  try {
    final now = targetDate ?? DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    final startDt = DateTime.parse(rawStart.toString().trim()).toLocal();
    final endDt = DateTime.parse(rawEnd.toString().trim()).toLocal();

    final startStr = DateFormat('yyyy-MM-dd').format(startDt);
    final endStr = DateFormat('yyyy-MM-dd').format(endDt);

    // Start date <= today AND end date >= today (inclusive)
    return startStr.compareTo(todayStr) <= 0 && endStr.compareTo(todayStr) >= 0;
  } catch (_) {
    return false;
  }
}

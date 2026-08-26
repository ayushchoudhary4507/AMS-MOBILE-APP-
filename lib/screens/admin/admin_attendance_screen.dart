import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_provider.dart';
import '../../services/attendance_service.dart';
import '../../widgets/common/app_avatar.dart';

class AdminAttendanceLeavesScreen extends ConsumerStatefulWidget {
  const AdminAttendanceLeavesScreen({super.key});

  @override
  ConsumerState<AdminAttendanceLeavesScreen> createState() => _AdminAttendanceLeavesScreenState();
}

class _AdminAttendanceLeavesScreenState extends ConsumerState<AdminAttendanceLeavesScreen> {
  int _activeTab = 0; // 0: Attendance Today, 1: Leave Requests
  String _leaveFilter = 'All'; // All | Pending | Approved | Rejected
  String _attendanceSearch = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll();
    });
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      ref.read(attendanceProvider.notifier).loadStats(),
      ref.read(attendanceProvider.notifier).loadTodayAllAttendance(),
      ref.read(attendanceProvider.notifier).loadAllLeaves(),
      ref.read(employeeProvider.notifier).loadEmployees(),
    ]);
  }

  // ── LEAVE APPROVAL / REJECTION ─────────────────────────────────────────────
  Future<void> _handleLeaveAction(String leaveId, String status, String empName) async {
    final sm = ScaffoldMessenger.of(context);
    final isApprove = status.toLowerCase() == 'approved';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text(isApprove ? 'Approve Leave' : 'Reject Leave', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to ${isApprove ? 'APPROVE' : 'REJECT'} leave application for $empName?', style: TextStyle(color: context.txtSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isApprove ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isApprove ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final res = await AttendanceService.approveRejectLeave(leaveId: leaveId, status: isApprove ? 'Approved' : 'Rejected');
      if (!mounted) return;
      if (res['success'] == true || res['status'] == true) {
        sm.showSnackBar(SnackBar(
          content: Text('Leave request $status successfully! ✓'),
          backgroundColor: isApprove ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ));
        _refreshAll();
      } else {
        sm.showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Failed to update leave status'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      sm.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // ── MARK ATTENDANCE MODAL ──────────────────────────────────────────────────
  void _showMarkAttendanceModal(BuildContext context, {String? preselectedEmpId}) {
    final employees = ref.read(employeeProvider).employees;
    if (employees.isEmpty) return;

    String selectedEmpId = preselectedEmpId ?? (employees[0]['_id'] ?? employees[0]['id'])?.toString() ?? '';
    String status = 'Present';
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text('Mark Employee Attendance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.txtPrimary)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Employee Dropdown
                  Text('Select Employee', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.txtPrimary)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: context.borderCol),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedEmpId,
                        isExpanded: true,
                        dropdownColor: context.cardBg,
                        items: employees.map((e) {
                          final id = (e['_id'] ?? e['id'])?.toString() ?? '';
                          final name = (e['name'] ?? 'Staff').toString();
                          final dept = (e['department'] ?? '').toString();
                          return DropdownMenuItem(value: id, child: Text('$name ${dept.isNotEmpty ? '($dept)' : ''}', style: TextStyle(color: context.txtPrimary, fontSize: 13)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedEmpId = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Status Dropdown
                  Text('Attendance Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.txtPrimary)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: context.borderCol),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: status,
                        isExpanded: true,
                        dropdownColor: context.cardBg,
                        items: ['Present', 'Late', 'Half Day', 'Absent'].map((s) {
                          return DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: context.txtPrimary, fontSize: 13)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => status = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: 'Notes (Optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: context.isDark ? const Color(0xFF13162A) : const Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final sm = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);

                        try {
                          final res = await AttendanceService.adminMarkAttendance(
                            employeeId: selectedEmpId,
                            status: status,
                            notes: notesCtrl.text.trim(),
                          );
                          if (!mounted) return;
                          if (res['success'] == true) {
                            sm.showSnackBar(const SnackBar(content: Text('Attendance recorded ✓'), backgroundColor: Color(0xFF10B981)));
                            _refreshAll();
                          } else {
                            sm.showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Failed to mark attendance'), backgroundColor: Colors.red));
                          }
                        } catch (e) {
                          if (!mounted) return;
                          sm.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                        }
                      },
                      child: const Text('Save Attendance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final attendance = ref.watch(attendanceProvider);
    final employeeState = ref.watch(employeeProvider);
    final allEmployees = employeeState.employees;

    final todayAll = attendance.todayAllAttendance;
    final allLeaves = attendance.allLeaves;

    // Filter sets for today's status
    final Set<String> presentIds = {};
    for (final a in todayAll) {
      if (a is Map) {
        final id = (a['employeeId'] is Map ? a['employeeId']['_id'] : a['employeeId'])?.toString() ??
            (a['userId'] is Map ? a['userId']['_id'] : a['userId'])?.toString() ??
            a['_id']?.toString();
        if (id != null) presentIds.add(id);
      }
    }

    final Set<String> leaveIds = {};
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    for (final l in allLeaves) {
      if (l is Map) {
        final status = (l['status'] ?? '').toString().toLowerCase();
        if (status == 'approved' || status == 'pending') {
          final start = (l['startDate'] ?? '').toString().split('T').first;
          final end = (l['endDate'] ?? '').toString().split('T').first;
          if (todayStr.compareTo(start) >= 0 && todayStr.compareTo(end) <= 0) {
            final id = (l['employeeId'] is Map ? l['employeeId']['_id'] : l['employeeId'])?.toString() ??
                (l['userId'] is Map ? l['userId']['_id'] : l['userId'])?.toString();
            if (id != null) leaveIds.add(id);
          }
        }
      }
    }

    final presentCount = presentIds.length;
    final leaveCount = leaveIds.length;
    final absentCount = (allEmployees.length - presentCount - leaveCount).clamp(0, allEmployees.length);

    // Leave counts
    final pendingLeaves = allLeaves.where((l) => l is Map && (l['status'] ?? '').toString().toLowerCase() == 'pending').toList();
    final approvedLeaves = allLeaves.where((l) => l is Map && (l['status'] ?? '').toString().toLowerCase() == 'approved').toList();
    final rejectedLeaves = allLeaves.where((l) => l is Map && ['rejected', 'cancelled'].contains((l['status'] ?? '').toString().toLowerCase())).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Attendance & Leaves',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: context.txtPrimary, letterSpacing: -0.3),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.txtPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(auth.isAdmin ? '/admin/dashboard' : '/employee/dashboard');
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.txtPrimary),
            tooltip: 'Refresh',
            onPressed: _refreshAll,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: context.mainBgGradient),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshAll,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dual Tab Switcher (Attendance Today vs Leave Approvals)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderCol),
                    ),
                    child: Row(
                      children: [
                        _buildTabButton(0, "Today's Attendance ($presentCount)", Icons.calendar_today_rounded),
                        _buildTabButton(1, "Leave Requests (${pendingLeaves.length})", Icons.beach_access_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_activeTab == 0) ...[
                    // ── TAB 1: ATTENDANCE TODAY ──
                    Row(
                      children: [
                        _buildSummaryCard('Present', '$presentCount', const Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        _buildSummaryCard('On Leave', '$leaveCount', const Color(0xFFF59E0B)),
                        const SizedBox(width: 6),
                        _buildSummaryCard('Absent', '$absentCount', const Color(0xFFEF4444)),
                        const SizedBox(width: 6),
                        _buildSummaryCard('Total', '${allEmployees.length}', const Color(0xFF6366F1)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Search & Mark Action Bar
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: context.cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.borderCol),
                            ),
                            child: TextField(
                              textAlignVertical: TextAlignVertical.center,
                              style: TextStyle(color: context.txtPrimary, fontSize: 13.5),
                              decoration: InputDecoration(
                                hintText: 'Search staff by name or email...',
                                hintStyle: TextStyle(color: context.txtMuted, fontSize: 12.5),
                                prefixIcon: Icon(Icons.search_rounded, size: 19, color: context.txtMuted),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              onChanged: (val) => setState(() => _attendanceSearch = val),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 1,
                          ),
                          icon: const Icon(Icons.add_task_rounded, size: 17),
                          label: const Text('Mark Staff', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () => _showMarkAttendanceModal(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildAttendanceList(allEmployees, todayAll, presentIds, leaveIds),
                  ] else ...[
                    // ── TAB 2: LEAVE APPROVALS ──
                    Row(
                      children: [
                        _buildSummaryCard('All', '${allLeaves.length}', const Color(0xFF6366F1)),
                        const SizedBox(width: 6),
                        _buildSummaryCard('Pending', '${pendingLeaves.length}', const Color(0xFFF59E0B)),
                        const SizedBox(width: 6),
                        _buildSummaryCard('Approved', '${approvedLeaves.length}', const Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        _buildSummaryCard('Rejected', '${rejectedLeaves.length}', const Color(0xFFEF4444)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Filter tabs for Leaves
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: ['All', 'Pending', 'Approved', 'Rejected'].map((st) {
                          final isSel = _leaveFilter == st;
                          Color col = const Color(0xFF6366F1);
                          if (st == 'Pending') col = const Color(0xFFF59E0B);
                          if (st == 'Approved') col = const Color(0xFF10B981);
                          if (st == 'Rejected') col = const Color(0xFFEF4444);

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(st),
                              selected: isSel,
                              selectedColor: col,
                              labelStyle: TextStyle(color: isSel ? Colors.white : context.txtPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                              onSelected: (_) => setState(() => _leaveFilter = st),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildLeavesList(allLeaves),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSel = _activeTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFF6366F1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSel ? Colors.white : context.txtSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(color: isSel ? Colors.white : context.txtSecondary, fontWeight: isSel ? FontWeight.w800 : FontWeight.w600, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.txtMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ── ATTENDANCE LIST BUILDER ────────────────────────────────────────────────
  Widget _buildAttendanceList(List<dynamic> allEmployees, List<dynamic> todayAll, Set<String> presentIds, Set<String> leaveIds) {
    final filtered = allEmployees.where((emp) {
      if (emp is! Map) return false;
      final name = (emp['name'] ?? '').toString().toLowerCase();
      final email = (emp['email'] ?? '').toString().toLowerCase();
      final q = _attendanceSearch.toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('No employees found', style: TextStyle(color: context.txtMuted)),
        ),
      );
    }

    return Column(
      children: filtered.map((emp) {
        if (emp is! Map) return const SizedBox.shrink();
        final id = (emp['_id'] ?? emp['id'])?.toString() ?? '';
        final name = (emp['name'] ?? 'Staff').toString();
        final email = (emp['email'] ?? '').toString();
        final dept = (emp['department'] ?? emp['designation'] ?? 'General').toString();

        final isPresent = presentIds.contains(id);
        final isLeave = leaveIds.contains(id);

        Color statusColor = const Color(0xFFEF4444);
        String statusText = 'Absent';
        if (isPresent) {
          statusColor = const Color(0xFF10B981);
          statusText = 'Present';
        } else if (isLeave) {
          statusColor = const Color(0xFFF59E0B);
          statusText = 'On Leave';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderCol),
          ),
          child: Row(
            children: [
              AppAvatar(avatarOrUser: emp, fallbackText: name, radius: 20, backgroundColor: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.txtPrimary)),
                    Text('$dept • $email', style: TextStyle(fontSize: 11, color: context.txtMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _showMarkAttendanceModal(context, preselectedEmpId: id),
                    child: const Text('Edit / Mark', style: TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── LEAVES LIST BUILDER ────────────────────────────────────────────────────
  Widget _buildLeavesList(List<dynamic> allLeaves) {
    final filtered = allLeaves.where((l) {
      if (l is! Map) return false;
      final st = (l['status'] ?? '').toString().toLowerCase();
      if (_leaveFilter == 'Pending' && st != 'pending') return false;
      if (_leaveFilter == 'Approved' && st != 'approved') return false;
      if (_leaveFilter == 'Rejected' && !['rejected', 'cancelled'].contains(st)) return false;
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('No leave applications matching "$_leaveFilter"', style: TextStyle(color: context.txtMuted)),
        ),
      );
    }

    return Column(
      children: filtered.map((leave) {
        if (leave is! Map) return const SizedBox.shrink();
        final id = leave['_id']?.toString() ?? '';
        final empObj = leave['employeeId'] ?? leave['userId'];
        String empName = 'Staff Member';
        String empDept = 'General';
        if (empObj is Map) {
          empName = (empObj['name'] ?? 'Staff Member').toString();
          empDept = (empObj['department'] ?? empObj['designation'] ?? 'General').toString();
        }

        final leaveType = (leave['leaveType'] ?? leave['type'] ?? 'Leave').toString();
        final reason = (leave['reason'] ?? 'No reason provided').toString();
        final status = (leave['status'] ?? 'Pending').toString();
        final isPending = status.toLowerCase() == 'pending';

        final start = (leave['startDate'] ?? '').toString().split('T').first;
        final end = (leave['endDate'] ?? '').toString().split('T').first;
        final dateRange = start == end ? start : '$start to $end';

        Color statusColor = const Color(0xFFF59E0B);
        if (status.toLowerCase() == 'approved') statusColor = const Color(0xFF10B981);
        if (['rejected', 'cancelled'].contains(status.toLowerCase())) statusColor = const Color(0xFFEF4444);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
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
                  AppAvatar(avatarOrUser: empObj, fallbackText: empName, radius: 18, backgroundColor: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(empName, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.txtPrimary)),
                        Text(empDept, style: TextStyle(fontSize: 11, color: context.txtMuted)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(status, style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: context.borderCol.withValues(alpha: 0.4), height: 1),
              const SizedBox(height: 8),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(leaveType, style: const TextStyle(color: Color(0xFF6366F1), fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF6366F1)),
                  const SizedBox(width: 4),
                  Text(dateRange, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.txtSecondary)),
                ],
              ),
              const SizedBox(height: 6),
              Text(reason, style: TextStyle(fontSize: 12, color: context.txtMuted), maxLines: 2, overflow: TextOverflow.ellipsis),

              if (isPending) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () => _handleLeaveAction(id, 'Rejected', empName),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () => _handleLeaveAction(id, 'Approved', empName),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

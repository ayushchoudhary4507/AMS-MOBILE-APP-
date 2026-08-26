 import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_provider.dart';
import '../../services/attendance_service.dart';
import '../../widgets/common/app_avatar.dart';

class AdminWorkHoursScreen extends ConsumerStatefulWidget {
  const AdminWorkHoursScreen({super.key});

  @override
  ConsumerState<AdminWorkHoursScreen> createState() => _AdminWorkHoursScreenState();
}

class _AdminWorkHoursScreenState extends ConsumerState<AdminWorkHoursScreen> {
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  String _statusFilter = 'All'; // All | Active Now | Checked Out | Not Checked In
  bool _isLoading = false;
  List<dynamic> _attendanceList = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchWorkHours();
      ref.read(employeeProvider.notifier).loadEmployees();
    });
  }

  Future<void> _fetchWorkHours() async {
    setState(() => _isLoading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateStr;
      final res = isToday 
          ? await AttendanceService.getTodayAllAttendance()
          : await AttendanceService.getAttendanceByDate(dateStr);
          
      final list = res['data'] ?? res['attendance'] ?? res['records'] ?? [];
      if (mounted) {
        setState(() {
          _attendanceList = list is List ? list : [];
        });
      }
    } catch (_) {
      if (mounted) setState(() => _attendanceList = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final employeeState = ref.watch(employeeProvider);
    final allEmployees = employeeState.employees;
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) == DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Map all employees to work hour records
    final Map<String, dynamic> attMap = {};
    for (final a in _attendanceList) {
      if (a is Map) {
        final empId = (a['employeeId'] is Map ? a['employeeId']['_id'] : a['employeeId'])?.toString() ??
            (a['userId'] is Map ? a['userId']['_id'] : a['userId'])?.toString() ??
            a['_id']?.toString() ?? '';
        if (empId.isNotEmpty) attMap[empId] = a;
      }
    }

    final List<Map<String, dynamic>> combinedList = [];
    double totalLoggedHours = 0;
    int activeCount = 0;
    int checkedOutCount = 0;

    for (final emp in allEmployees) {
      if (emp is! Map) continue;
      final id = (emp['_id'] ?? emp['id'])?.toString() ?? '';
      final att = attMap[id];

      String inTime = 'Not Checked In';
      String outTime = '--';
      double hours = 0.0;
      String status = 'Not Checked In';

      if (att != null) {
        final checkInRaw = att['checkInTime'] ?? att['inTime'] ?? att['time'];
        final checkOutRaw = att['checkOutTime'] ?? att['outTime'];

        if (checkInRaw != null) {
          try {
            final dt = DateTime.parse(checkInRaw.toString()).toLocal();
            inTime = DateFormat('hh:mm a').format(dt);
          } catch (_) {
            inTime = checkInRaw.toString();
          }

          if (checkOutRaw != null && checkOutRaw.toString().isNotEmpty) {
            try {
              final dt = DateTime.parse(checkOutRaw.toString()).toLocal();
              outTime = DateFormat('hh:mm a').format(dt);
            } catch (_) {
              outTime = checkOutRaw.toString();
            }
            status = 'Checked Out';
            checkedOutCount++;
          } else {
            outTime = isToday ? 'Active Now' : 'Not Recorded';
            status = isToday ? 'Active Now' : 'Checked In';
            activeCount++;
          }
        }

        // Calculate hours
        if (att['workHours'] != null) {
          hours = double.tryParse(att['workHours'].toString()) ?? 0;
        } else if (checkInRaw != null) {
          try {
            final inDt = DateTime.parse(checkInRaw.toString());
            final outDt = checkOutRaw != null ? DateTime.parse(checkOutRaw.toString()) : (isToday ? DateTime.now() : inDt.add(const Duration(hours: 8)));
            hours = outDt.difference(inDt).inMinutes / 60.0;
            if (hours < 0) hours = 0;
          } catch (_) {
            hours = 8.0;
          }
        }
        totalLoggedHours += hours;
      }

      combinedList.add({
        'employee': emp,
        'name': (emp['name'] ?? 'Staff').toString(),
        'email': (emp['email'] ?? '').toString(),
        'department': (emp['department'] ?? emp['designation'] ?? 'General').toString(),
        'inTime': inTime,
        'outTime': outTime,
        'hours': hours,
        'status': status,
        'hasAttendance': att != null,
      });
    }

    // Filter list
    final filtered = combinedList.where((item) {
      final name = item['name'].toString().toLowerCase();
      final email = item['email'].toString().toLowerCase();
      final dept = item['department'].toString().toLowerCase();
      final st = item['status'].toString();

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!name.contains(q) && !email.contains(q) && !dept.contains(q)) return false;
      }

      if (_statusFilter != 'All') {
        if (_statusFilter == 'Active Now' && st != 'Active Now') return false;
        if (_statusFilter == 'Checked Out' && st != 'Checked Out') return false;
        if (_statusFilter == 'Not Checked In' && st != 'Not Checked In') return false;
      }

      return true;
    }).toList();

    final avgHours = allEmployees.isNotEmpty ? (totalLoggedHours / (activeCount + checkedOutCount > 0 ? (activeCount + checkedOutCount) : 1)) : 0.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Work Hours Tracker',
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
            onPressed: _fetchWorkHours,
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
            onRefresh: _fetchWorkHours,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Picker Bar (Previous / Date Picker / Next)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderCol),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.chevron_left_rounded, size: 22),
                          onPressed: () {
                            setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
                            _fetchWorkHours();
                          },
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2023),
                                lastDate: DateTime.now().add(const Duration(days: 30)),
                              );
                              if (picked != null) {
                                setState(() => _selectedDate = picked);
                                _fetchWorkHours();
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_month_rounded, color: Color(0xFF6366F1), size: 16),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    DateFormat('EEE, d MMM yyyy').format(_selectedDate),
                                    style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isToday) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('TODAY', style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.w800)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.chevron_right_rounded, size: 22),
                          onPressed: () {
                            setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
                            _fetchWorkHours();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4 Summary Metrics (Exact match with EmployeeWorkHours.jsx)
                  Row(
                    children: [
                      _buildMetricCard('Total Staff', '${allEmployees.length}', const Color(0xFF6366F1)),
                      const SizedBox(width: 6),
                      _buildMetricCard('Active Staff', '$activeCount', const Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      _buildMetricCard('Total Hours', '${totalLoggedHours.toStringAsFixed(1)}h', const Color(0xFF3B82F6)),
                      const SizedBox(width: 6),
                      _buildMetricCard('Avg Hours', '${avgHours.toStringAsFixed(1)}h', const Color(0xFF8B5CF6)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Search Box
                  Container(
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
                        hintText: 'Search employee by name, email, department...',
                        hintStyle: TextStyle(color: context.txtMuted, fontSize: 12.5),
                        prefixIcon: Icon(Icons.search_rounded, size: 19, color: context.txtMuted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: ['All', 'Active Now', 'Checked Out', 'Not Checked In'].map((filter) {
                        final isSel = _statusFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: isSel,
                            selectedColor: const Color(0xFF6366F1),
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : context.txtPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) => setState(() => _statusFilter = filter),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Staff Work Hours List
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    )
                  else if (filtered.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderCol),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.access_time_filled_outlined, size: 48, color: context.txtMuted.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text('No records found for this date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.txtPrimary)),
                        ],
                      ),
                    )
                  else
                    ...filtered.map((item) => _buildWorkHourCard(item)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
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
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.txtMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkHourCard(Map<String, dynamic> item) {
    final emp = item['employee'];
    final name = item['name'].toString();
    final dept = item['department'].toString();
    final inTime = item['inTime'].toString();
    final outTime = item['outTime'].toString();
    final hours = (item['hours'] as num).toDouble();
    final status = item['status'].toString();

    Color statusColor = const Color(0xFFEF4444);
    if (status == 'Active Now') statusColor = const Color(0xFF10B981);
    if (status == 'Checked Out') statusColor = const Color(0xFF3B82F6);

    final progress = (hours / 8.0).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderCol.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.15 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              AppAvatar(
                avatarOrUser: emp,
                fallbackText: name,
                radius: 20,
                backgroundColor: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.txtPrimary),
                    ),
                    Text(
                      dept,
                      style: TextStyle(fontSize: 11, color: context.txtMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: context.borderCol.withValues(alpha: 0.4), height: 1),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('In: $inTime', style: TextStyle(fontSize: 11.5, color: context.txtSecondary, fontWeight: FontWeight.w600)),
                    Text('Out: $outTime', style: TextStyle(fontSize: 11.5, color: context.txtMuted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${hours.toStringAsFixed(1)} / 8.0 hrs',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: hours >= 8.0 ? const Color(0xFF10B981) : const Color(0xFF6366F1)),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 90,
                    height: 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: context.borderCol,
                        valueColor: AlwaysStoppedAnimation<Color>(hours >= 8.0 ? const Color(0xFF10B981) : const Color(0xFF6366F1)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

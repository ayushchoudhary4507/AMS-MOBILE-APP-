import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/employee_service.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  int _viewMonth = DateTime.now().month;
  int _viewYear = DateTime.now().year;
  String _searchQuery = '';
  bool _isLoading = false;
  List<dynamic> _reports = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchReports();
    });
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final res = await ReportService.getAllMonthlyReports(month: _viewMonth, year: _viewYear);
      final list = res['data'] ?? res['reports'] ?? res['records'] ?? [];
      if (mounted) {
        setState(() {
          _reports = list is List ? list : [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _reports = []);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM').format(DateTime(_viewYear, _viewMonth));

    // Filter reports by search query
    final filteredReports = _reports.where((r) {
      if (r is! Map) return false;
      if (_searchQuery.isEmpty) return true;
      final name = (r['employeeName'] ?? r['name'] ?? '').toString().toLowerCase();
      final email = (r['employeeEmail'] ?? r['email'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();

    // Calculate totals across reports (exact parity with MonthlyReports.jsx)
    int totalPresent = 0;
    int totalAbsent = 0;
    int totalLeave = 0;
    int totalLate = 0;
    double totalSalary = 0;

    for (final r in filteredReports) {
      if (r is! Map) continue;
      final att = r['attendance'];
      if (att is Map) {
        totalPresent += (int.tryParse((att['totalPresent'] ?? 0).toString()) ?? 0);
        totalAbsent += (int.tryParse((att['totalAbsent'] ?? 0).toString()) ?? 0);
        totalLeave += (int.tryParse((att['totalLeave'] ?? 0).toString()) ?? 0);
        totalLate += (int.tryParse((att['lateCount'] ?? 0).toString()) ?? 0);
      }
      final sal = r['salary'];
      if (sal is Map) {
        final f = (sal['finalSalary'] ?? sal['netPay'] ?? 0);
        totalSalary += (double.tryParse(f.toString()) ?? 0);
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Monthly Reports',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: context.txtPrimary,
            letterSpacing: -0.3,
          ),
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
              final auth = ref.read(authProvider);
              context.go(auth.isAdmin ? '/admin/dashboard' : '/employee/dashboard');
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.txtPrimary),
            tooltip: 'Refresh',
            onPressed: _fetchReports,
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
            onRefresh: _fetchReports,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month & Year Selector
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderCol),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: Color(0xFF6366F1), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _viewMonth,
                              dropdownColor: context.cardBg,
                              isDense: true,
                              items: List.generate(12, (i) => i + 1).map((m) {
                                final name = DateFormat('MMMM').format(DateTime(2025, m));
                                return DropdownMenuItem(value: m, child: Text(name, style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.bold, fontSize: 13)));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _viewMonth = val);
                                  _fetchReports();
                                }
                              },
                            ),
                          ),
                        ),
                        Container(width: 1, height: 24, color: context.borderCol),
                        const SizedBox(width: 12),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _viewYear,
                            dropdownColor: context.cardBg,
                            isDense: true,
                            items: [2024, 2025, 2026, 2027].map((y) {
                              return DropdownMenuItem(value: y, child: Text('$y', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.bold, fontSize: 13)));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _viewYear = val);
                                _fetchReports();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

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
                        hintText: 'Search employees by name or email...',
                        hintStyle: TextStyle(color: context.txtMuted, fontSize: 12.5),
                        prefixIcon: Icon(Icons.search_rounded, size: 19, color: context.txtMuted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5 Summary Cards (Exact match with MonthlyReports.jsx)
                  Row(
                    children: [
                      _buildSummaryStatCard(context, 'Present', '$totalPresent', const Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      _buildSummaryStatCard(context, 'Absent', '$totalAbsent', const Color(0xFFEF4444)),
                      const SizedBox(width: 6),
                      _buildSummaryStatCard(context, 'Leave', '$totalLeave', const Color(0xFFF59E0B)),
                      const SizedBox(width: 6),
                      _buildSummaryStatCard(context, 'Late', '$totalLate', const Color(0xFF8B5CF6)),
                      const SizedBox(width: 6),
                      _buildSummaryStatCard(context, 'Salary', '₹${_formatAmount(totalSalary)}', const Color(0xFF06B6D4), isTotal: true),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Section Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Employee Summaries ($monthName $_viewYear)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.txtPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        '${filteredReports.length} employees',
                        style: TextStyle(fontSize: 12, color: context.txtMuted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Reports List
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    )
                  else if (filteredReports.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderCol),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.assessment_outlined, size: 48, color: context.txtMuted.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text('No reports found for $monthName $_viewYear', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.txtPrimary)),
                          const SizedBox(height: 6),
                          Text('Employee monthly attendance and salary reports will appear here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: context.txtMuted)),
                        ],
                      ),
                    )
                  else
                    ...filteredReports.map((r) => _buildReportCard(context, r)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryStatCard(BuildContext context, String label, String value, Color color, {bool isTotal = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isTotal ? color.withValues(alpha: 0.5) : context.borderCol),
          boxShadow: isTotal
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: isTotal ? 11.5 : 14,
                fontWeight: FontWeight.w800,
                color: isTotal ? color : context.txtPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: context.txtMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, dynamic report) {
    if (report is! Map) return const SizedBox.shrink();

    final name = (report['employeeName'] ?? report['name'] ?? 'Staff Member').toString();
    final email = (report['employeeEmail'] ?? report['email'] ?? '').toString();
    final desig = (report['designation'] ?? report['department'] ?? 'Employee').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    final att = report['attendance'] is Map ? report['attendance'] : {};
    final present = att['totalPresent'] ?? 0;
    final absent = att['totalAbsent'] ?? 0;
    final leave = att['totalLeave'] ?? 0;
    final late = att['lateCount'] ?? 0;
    final hours = double.tryParse((att['totalWorkingHours'] ?? 0).toString()) ?? 0;

    final sal = report['salary'] is Map ? report['salary'] : null;
    final finalSalary = sal != null ? (double.tryParse((sal['finalSalary'] ?? 0).toString()) ?? 0) : null;
    final isPaid = sal != null && sal['isPaid'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderCol.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.14 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avatar, Name, Email, Designation, Paid status
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: context.txtPrimary,
                      ),
                    ),
                    Text(
                      '$desig ${email.isNotEmpty ? '• $email' : ''}',
                      style: TextStyle(fontSize: 11, color: context.txtMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (sal != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isPaid ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPaid ? 'Paid' : 'Unpaid',
                    style: TextStyle(
                      color: isPaid ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.txtMuted.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'N/A',
                    style: TextStyle(color: context.txtMuted, fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Row 2: Attendance breakdown badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _attBadge('Present', '$present', const Color(0xFF10B981)),
              _attBadge('Absent', '$absent', const Color(0xFFEF4444)),
              _attBadge('Leave', '$leave', const Color(0xFFF59E0B)),
              _attBadge('Late', '$late', const Color(0xFF8B5CF6)),
              _attBadge('Hours', '${hours.toStringAsFixed(1)}h', const Color(0xFF3B82F6)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Final Salary', style: TextStyle(fontSize: 9.5, color: context.txtMuted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    finalSalary != null ? '₹${_formatAmount(finalSalary)}' : 'N/A',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: finalSalary != null ? const Color(0xFF10B981) : context.txtMuted,
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

  Widget _attBadge(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 9.5, color: color, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
          ),
        ),
      ],
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)}L';
    }
    return NumberFormat('#,##,###').format(amount);
  }
}

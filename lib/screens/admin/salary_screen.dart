import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_provider.dart';
import '../../services/employee_service.dart';
import '../../widgets/common/app_avatar.dart';

class AdminSalaryScreen extends ConsumerStatefulWidget {
  const AdminSalaryScreen({super.key});

  @override
  ConsumerState<AdminSalaryScreen> createState() => _AdminSalaryScreenState();
}

class _AdminSalaryScreenState extends ConsumerState<AdminSalaryScreen> {
  int _viewMonth = DateTime.now().month;
  int _viewYear = DateTime.now().year;
  bool _isLoading = false;
  List<dynamic> _salaries = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSalaries();
      ref.read(employeeProvider.notifier).loadEmployees();
    });
  }

  Future<void> _fetchSalaries() async {
    setState(() => _isLoading = true);
    try {
      final res = await SalaryService.getAll(month: _viewMonth, year: _viewYear);
      final list = res['data'] ?? res['salaries'] ?? res['records'] ?? [];
      if (mounted) {
        setState(() {
          _salaries = list is List ? list : [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _salaries = []);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── CALCULATE SALARY MODAL ──────────────────────────────────────────────────
  void _showCalculateModal(BuildContext context, List<dynamic> employees) {
    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No employees found to calculate salary for')),
      );
      return;
    }

    String selectedEmpId = (employees[0]['_id'] ?? employees[0]['id'])?.toString() ?? '';
    final basicCtrl = TextEditingController(text: '20000');
    final perDayCtrl = TextEditingController();
    final perHourCtrl = TextEditingController();
    final deductionsCtrl = TextEditingController(text: '0');
    final bonusCtrl = TextEditingController(text: '0');
    final overtimeCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.90),
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.calculate_rounded, color: Color(0xFF10B981), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Calculate Employee Salary',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.txtPrimary),
                            ),
                            Text(
                              DateFormat('MMMM yyyy').format(DateTime(_viewYear, _viewMonth)),
                              style: TextStyle(fontSize: 12, color: context.txtMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Employee Dropdown
                    Text('Select Employee', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.txtPrimary)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: context.borderCol),
                        borderRadius: BorderRadius.circular(12),
                        color: context.isDark ? const Color(0xFF13162A) : const Color(0xFFF8FAFC),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedEmpId,
                          isExpanded: true,
                          dropdownColor: context.cardBg,
                          items: employees.map((emp) {
                            final id = (emp['_id'] ?? emp['id'])?.toString() ?? '';
                            final name = (emp['name'] ?? 'Staff').toString();
                            final desig = (emp['designation'] ?? emp['department'] ?? '').toString();
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text('$name ${desig.isNotEmpty ? '($desig)' : ''}', style: TextStyle(color: context.txtPrimary, fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedEmpId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Basic Salary
                    TextField(
                      controller: basicCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Basic Salary (₹)',
                        prefixIcon: const Icon(Icons.currency_rupee_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: context.isDark ? const Color(0xFF13162A) : const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Per Day & Per Hour Salary
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: perDayCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Per Day (₹)',
                              hintText: 'Auto if empty',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: context.isDark ? const Color(0xFF13162A) : const Color(0xFFF8FAFC),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: perHourCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Per Hour (₹)',
                              hintText: 'Auto if empty',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: context.isDark ? const Color(0xFF13162A) : const Color(0xFFF8FAFC),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Deductions & Bonus
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: deductionsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Deductions (₹)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: context.isDark ? const Color(0xFF13162A) : const Color(0xFFF8FAFC),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: bonusCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Bonus (₹)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: context.isDark ? const Color(0xFF13162A) : const Color(0xFFF8FAFC),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Overtime & Notes
                    TextField(
                      controller: overtimeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Overtime Pay (₹)',
                        prefixIcon: const Icon(Icons.access_time_filled_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: context.isDark ? const Color(0xFF13162A) : const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: notesCtrl,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        prefixIcon: const Icon(Icons.notes_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: context.isDark ? const Color(0xFF13162A) : const Color(0xFFF8FAFC),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final sm = ScaffoldMessenger.of(context);
                          final basic = double.tryParse(basicCtrl.text.trim()) ?? 20000;
                          final perDay = double.tryParse(perDayCtrl.text.trim()) ?? 0;
                          final perHour = double.tryParse(perHourCtrl.text.trim()) ?? 0;
                          final deductions = double.tryParse(deductionsCtrl.text.trim()) ?? 0;
                          final bonus = double.tryParse(bonusCtrl.text.trim()) ?? 0;
                          final overtime = double.tryParse(overtimeCtrl.text.trim()) ?? 0;

                          Navigator.pop(ctx);
                          setState(() => _isLoading = true);
                          try {
                            final res = await SalaryService.calculateSalary({
                              'employeeId': selectedEmpId,
                              'month': _viewMonth,
                              'year': _viewYear,
                              'basicSalary': basic,
                              'perDaySalary': perDay,
                              'perHourSalary': perHour,
                              'deductions': deductions,
                              'bonus': bonus,
                              'overtimePay': overtime,
                              'notes': notesCtrl.text.trim(),
                            });
                            if (!mounted) return;
                            if (res['success'] == true) {
                              sm.showSnackBar(
                                const SnackBar(content: Text('Salary calculated successfully! ✓'), backgroundColor: Color(0xFF10B981)),
                              );
                              _fetchSalaries();
                            } else {
                              sm.showSnackBar(
                                SnackBar(content: Text(res['message']?.toString() ?? 'Failed to calculate salary'), backgroundColor: Colors.red),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            sm.showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                        child: const Text('Calculate & Save Salary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

  // ── BULK CALCULATE ──────────────────────────────────────────────────────────
  Future<void> _handleBulkCalculate() async {
    final sm = ScaffoldMessenger.of(context);
    final monthName = DateFormat('MMMM yyyy').format(DateTime(_viewYear, _viewMonth));
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text('Bulk Calculate Salary', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.bold)),
        content: Text('Calculate salary for all employees for $monthName based on actual attendance records?', style: TextStyle(color: context.txtSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start Bulk Calc'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final res = await SalaryService.bulkCalculate(_viewMonth, _viewYear);
      if (!mounted) return;
      if (res['success'] == true) {
        sm.showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Bulk calculation completed! ✓'), backgroundColor: const Color(0xFF10B981)),
        );
        _fetchSalaries();
      } else {
        sm.showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Failed to perform bulk calculation'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      sm.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── MARK AS PAID HANDLER ────────────────────────────────────────────────────
  Future<void> _handleMarkPaid(String salaryId, String empName) async {
    final sm = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text('Mark Salary as Paid', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.bold)),
        content: Text('Mark salary for $empName as PAID?', style: TextStyle(color: context.txtSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Paid'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final res = await SalaryService.markAsPaid(salaryId);
      if (!mounted) return;
      if (res['success'] == true) {
        sm.showSnackBar(
          const SnackBar(content: Text('Salary marked as PAID ✓'), backgroundColor: Color(0xFF10B981)),
        );
        _fetchSalaries();
      } else {
        sm.showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Failed to mark as paid'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      sm.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeeState = ref.watch(employeeProvider);
    final allEmployees = employeeState.employees;

    // Summary calculations
    double totalPayroll = 0;
    int paidCount = 0;
    for (final s in _salaries) {
      if (s is Map) {
        final finalSal = (s['finalSalary'] ?? s['netPay'] ?? s['basicSalary'] ?? 0);
        totalPayroll += (double.tryParse(finalSal.toString()) ?? 0);
        final isPaid = s['isPaid'] == true || (s['status'] ?? '').toString().toLowerCase() == 'paid';
        if (isPaid) paidCount++;
      }
    }
    final unpaidCount = _salaries.length - paidCount;
    final monthName = DateFormat('MMMM').format(DateTime(_viewYear, _viewMonth));

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Salary Management',
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
            onPressed: _fetchSalaries,
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
            onRefresh: _fetchSalaries,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action Buttons (Calculate Salary & Bulk Calculate)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.calculate_rounded, size: 18),
                          label: const Text('Calculate Salary', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          onPressed: () => _showCalculateModal(context, allEmployees),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: context.cardBg,
                            foregroundColor: const Color(0xFF6366F1),
                            side: const BorderSide(color: Color(0xFF6366F1), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                          label: const Text('Bulk Calculate', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          onPressed: _handleBulkCalculate,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Month & Year Filter Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderCol),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: Color(0xFF10B981), size: 18),
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
                                  _fetchSalaries();
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
                                _fetchSalaries();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4 Summary Metrics (Exact match with website summary cards)
                  Row(
                    children: [
                      _buildSummaryStatCard(context, 'Calculated', '${_salaries.length}', const Color(0xFF6366F1)),
                      const SizedBox(width: 8),
                      _buildSummaryStatCard(context, 'Paid', '$paidCount', const Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      _buildSummaryStatCard(context, 'Unpaid', '$unpaidCount', const Color(0xFFEF4444)),
                      const SizedBox(width: 8),
                      _buildSummaryStatCard(context, 'Total', '₹${_formatAmount(totalPayroll)}', const Color(0xFF10B981), isTotal: true),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Section Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Salary Records ($monthName $_viewYear)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.txtPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        '${_salaries.length} records',
                        style: TextStyle(fontSize: 12, color: context.txtMuted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Salary Records List
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    )
                  else if (_salaries.isEmpty)
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
                          Icon(Icons.receipt_long_outlined, size: 48, color: context.txtMuted.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text('No salary records for $monthName $_viewYear', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.txtPrimary)),
                          const SizedBox(height: 6),
                          Text('Tap "Bulk Calculate" or "Calculate Salary" to generate payslips.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: context.txtMuted)),
                        ],
                      ),
                    )
                  else
                    ..._salaries.map((s) => _buildSalaryCard(context, s, allEmployees)),
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isTotal ? color.withValues(alpha: 0.5) : context.borderCol),
          boxShadow: isTotal
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: isTotal ? 13 : 16,
                fontWeight: FontWeight.w800,
                color: isTotal ? color : context.txtPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: context.txtMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryCard(BuildContext context, dynamic salary, List<dynamic> allEmployees) {
    if (salary is! Map) return const SizedBox.shrink();

    final id = salary['_id']?.toString() ?? '';
    final empObj = salary['employeeId'] ?? salary['userId'] ?? salary['employee'];
    String empName = 'Staff Member';
    String empEmail = '';
    String dept = '';

    if (empObj is Map) {
      empName = (empObj['name'] ?? 'Staff Member').toString();
      empEmail = (empObj['email'] ?? '').toString();
      dept = (empObj['department'] ?? empObj['designation'] ?? '').toString();
    } else {
      empName = (salary['employeeName'] ?? salary['name'] ?? 'Staff Member').toString();
    }

    final basic = double.tryParse((salary['basicSalary'] ?? 0).toString()) ?? 0;
    final presentDays = salary['totalPresentDays'] ?? salary['presentDays'] ?? 0;
    final workHours = double.tryParse((salary['totalWorkingHours'] ?? salary['workingHours'] ?? 0).toString()) ?? 0;
    final deductions = double.tryParse((salary['deductions'] ?? 0).toString()) ?? 0;
    final bonus = double.tryParse((salary['bonus'] ?? 0).toString()) ?? 0;
    final finalSalary = double.tryParse((salary['finalSalary'] ?? salary['netPay'] ?? basic).toString()) ?? basic;

    final isPaid = salary['isPaid'] == true || (salary['status'] ?? '').toString().toLowerCase() == 'paid';
    final statusColor = isPaid ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderCol.withValues(alpha: 0.7)),
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
          // Header: Employee Avatar & Name + Status Badge
          Row(
            children: [
              AppAvatar(
                avatarOrUser: empObj is Map ? empObj : salary,
                fallbackText: empName,
                radius: 20,
                backgroundColor: AppColors.primary,
              ),
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
                    if (empEmail.isNotEmpty || dept.isNotEmpty)
                      Text(
                        dept.isNotEmpty ? '$dept • $empEmail' : empEmail,
                        style: TextStyle(fontSize: 11, color: context.txtMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  isPaid ? 'Paid' : 'Unpaid',
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // 4-column metrics: Basic | Present/Hrs | Deductions/Bonus | Final Salary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metricColumn(context, 'Basic', '₹${_formatAmount(basic)}'),
              _metricColumn(context, 'Present', '$presentDays d (${workHours.toStringAsFixed(1)}h)'),
              _metricColumn(context, 'Ded / Bonus', '-₹${_formatAmount(deductions)} / +₹${_formatAmount(bonus)}'),
              _metricColumn(context, 'Final Salary', '₹${_formatAmount(finalSalary)}', isHighlight: true),
            ],
          ),

          if (!isPaid && id.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text('Mark as Paid', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                onPressed: () => _handleMarkPaid(id, empName),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricColumn(BuildContext context, String label, String value, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10.5, color: context.txtMuted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
            color: isHighlight ? const Color(0xFF10B981) : context.txtPrimary,
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

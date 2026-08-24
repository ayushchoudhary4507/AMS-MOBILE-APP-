import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_provider.dart';
import '../../widgets/common/app_avatar.dart';

class AdminSalaryScreen extends ConsumerStatefulWidget {
  const AdminSalaryScreen({super.key});

  @override
  ConsumerState<AdminSalaryScreen> createState() => _AdminSalaryScreenState();
}

class _AdminSalaryScreenState extends ConsumerState<AdminSalaryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(allSalaryProvider);
      ref.read(employeeProvider.notifier).loadEmployees();
    });
  }

  @override
  Widget build(BuildContext context) {
    final salaryAsync = ref.watch(allSalaryProvider);
    final employeeState = ref.watch(employeeProvider);

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
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: context.txtPrimary,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin/dashboard');
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.txtPrimary),
            onPressed: () {
              ref.invalidate(allSalaryProvider);
              ref.read(employeeProvider.notifier).loadEmployees();
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: context.mainBgGradient),
        child: SafeArea(
          child: salaryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => _buildEmptyState(context),
            data: (salaries) {
              if (salaries.isEmpty) return _buildEmptyState(context);
              return _buildContent(context, salaries, employeeState.employees);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<dynamic> salaries, List<dynamic> allEmployees) {
    // Summary stats
    double totalPayroll = 0;
    int processedCount = 0;
    for (final s in salaries) {
      if (s is Map) {
        final net = _resolveNetPay(s);
        totalPayroll += net;
        if (_resolveStatus(s) == 'Paid') {
          processedCount++;
        }
      }
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(allSalaryProvider);
        ref.read(employeeProvider.notifier).loadEmployees();
      },
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payroll Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Payroll',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹${_formatAmount(totalPayroll)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _heroStat('Total Staff', salaries.length.toString()),
                      const SizedBox(width: 24),
                      _heroStat('Processed', processedCount.toString()),
                      const SizedBox(width: 24),
                      _heroStat('Pending', (salaries.length - processedCount).toString()),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Employee Salaries',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.txtPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  '${salaries.length} records',
                  style: TextStyle(color: context.txtMuted, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ...salaries.map((s) => _buildSalaryCard(context, s, allEmployees)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildSalaryCard(BuildContext context, dynamic salary, List<dynamic> allEmployees) {
    if (salary is! Map) return const SizedBox.shrink();
    
    final empName = _resolveEmployeeName(salary, allEmployees);
    final empEmail = _resolveEmployeeEmail(salary, allEmployees);
    final dept = _resolveEmployeeDept(salary, allEmployees);
    final netPay = _resolveNetPay(salary);
    final status = _resolveStatus(salary);
    final monthYear = _resolveMonthYear(salary);
    final avatarData = _resolveAvatar(salary, allEmployees);

    final isPaid = status.toLowerCase() == 'paid' || status.toLowerCase() == 'processed';
    final statusColor = isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderCol.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.14 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AppAvatar(
            avatarOrUser: avatarData ?? salary,
            fallbackText: empName,
            radius: 22,
            backgroundColor: AppColors.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  empName,
                  style: TextStyle(
                    color: context.txtPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dept.isNotEmpty ? '$dept • $monthYear' : monthYear,
                  style: TextStyle(color: context.txtSecondary, fontSize: 12),
                ),
                if (empEmail.isNotEmpty)
                  Text(
                    empEmail,
                    style: TextStyle(color: context.txtMuted, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${_formatAmount(netPay)}',
                style: TextStyle(
                  color: context.txtPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _resolveEmployeeName(dynamic salary, List<dynamic> allEmployees) {
    if (salary is! Map) return 'Employee';
    final empIdObj = salary['employeeId'];
    if (empIdObj is Map && empIdObj['name'] != null && empIdObj['name'].toString().isNotEmpty) {
      return empIdObj['name'].toString();
    }
    final userObj = salary['userId'];
    if (userObj is Map && userObj['name'] != null && userObj['name'].toString().isNotEmpty) {
      return userObj['name'].toString();
    }
    final empObj = salary['employee'];
    if (empObj is Map && empObj['name'] != null && empObj['name'].toString().isNotEmpty) {
      return empObj['name'].toString();
    }
    if (salary['employeeName'] != null && salary['employeeName'].toString().isNotEmpty) {
      return salary['employeeName'].toString();
    }
    if (salary['name'] != null && salary['name'].toString().isNotEmpty) {
      return salary['name'].toString();
    }

    final targetId = (salary['employeeId'] ?? salary['userId'] ?? salary['employee'] ?? salary['_id'])?.toString();
    if (targetId != null && targetId.isNotEmpty) {
      for (final e in allEmployees) {
        if (e is Map) {
          final eId = (e['_id'] ?? e['id'] ?? e['userId'])?.toString();
          if (eId == targetId && e['name'] != null) {
            return e['name'].toString();
          }
        }
      }
    }
    return 'Employee';
  }

  String _resolveEmployeeEmail(dynamic salary, List<dynamic> allEmployees) {
    if (salary is! Map) return '';
    final empIdObj = salary['employeeId'];
    if (empIdObj is Map && empIdObj['email'] != null) return empIdObj['email'].toString();
    final userObj = salary['userId'];
    if (userObj is Map && userObj['email'] != null) return userObj['email'].toString();
    final empObj = salary['employee'];
    if (empObj is Map && empObj['email'] != null) return empObj['email'].toString();
    if (salary['email'] != null) return salary['email'].toString();

    final targetId = (salary['employeeId'] ?? salary['userId'] ?? salary['employee'])?.toString();
    if (targetId != null && targetId.isNotEmpty) {
      for (final e in allEmployees) {
        if (e is Map) {
          final eId = (e['_id'] ?? e['id'] ?? e['userId'])?.toString();
          if (eId == targetId && e['email'] != null) {
            return e['email'].toString();
          }
        }
      }
    }
    return '';
  }

  String _resolveEmployeeDept(dynamic salary, List<dynamic> allEmployees) {
    if (salary is! Map) return '';
    final empIdObj = salary['employeeId'];
    if (empIdObj is Map && empIdObj['designation'] != null) return empIdObj['designation'].toString();
    if (empIdObj is Map && empIdObj['department'] != null) return empIdObj['department'].toString();
    final empObj = salary['employee'];
    if (empObj is Map && empObj['designation'] != null) return empObj['designation'].toString();
    if (empObj is Map && empObj['department'] != null) return empObj['department'].toString();
    if (salary['designation'] != null) return salary['designation'].toString();
    if (salary['department'] != null) return salary['department'].toString();

    final targetId = (salary['employeeId'] ?? salary['userId'] ?? salary['employee'])?.toString();
    if (targetId != null && targetId.isNotEmpty) {
      for (final e in allEmployees) {
        if (e is Map) {
          final eId = (e['_id'] ?? e['id'] ?? e['userId'])?.toString();
          if (eId == targetId) {
            return (e['designation'] ?? e['department'] ?? e['role'] ?? '').toString();
          }
        }
      }
    }
    return '';
  }

  dynamic _resolveAvatar(dynamic salary, List<dynamic> allEmployees) {
    if (salary is! Map) return null;
    final empIdObj = salary['employeeId'];
    if (empIdObj is Map) {
      final av = extractAvatarUrl(empIdObj);
      if (av != null && av.isNotEmpty) return av;
    }
    final userObj = salary['userId'];
    if (userObj is Map) {
      final av = extractAvatarUrl(userObj);
      if (av != null && av.isNotEmpty) return av;
    }
    final empObj = salary['employee'];
    if (empObj is Map) {
      final av = extractAvatarUrl(empObj);
      if (av != null && av.isNotEmpty) return av;
    }
    final direct = extractAvatarUrl(salary);
    if (direct != null && direct.isNotEmpty) return direct;

    final targetId = (salary['employeeId'] ?? salary['userId'] ?? salary['employee'])?.toString();
    if (targetId != null && targetId.isNotEmpty) {
      for (final e in allEmployees) {
        if (e is Map) {
          final eId = (e['_id'] ?? e['id'] ?? e['userId'])?.toString();
          if (eId == targetId) {
            return extractAvatarUrl(e) ?? e;
          }
        }
      }
    }
    return null;
  }

  double _resolveNetPay(dynamic salary) {
    if (salary is! Map) return 0;
    final val = salary['finalSalary'] ??
        salary['netSalary'] ??
        salary['basicSalary'] ??
        salary['netPay'] ??
        salary['amount'] ??
        salary['baseSalary'] ??
        salary['salary'] ??
        0;
    return double.tryParse(val.toString()) ?? 0;
  }

  String _resolveMonthYear(dynamic salary) {
    if (salary is! Map) return DateFormat('MMMM yyyy').format(DateTime.now());
    final m = salary['month'];
    final y = salary['year'];
    if (m != null) {
      final mInt = int.tryParse(m.toString());
      final yInt = int.tryParse(y?.toString() ?? '') ?? DateTime.now().year;
      if (mInt != null && mInt >= 1 && mInt <= 12) {
        final dt = DateTime(yInt, mInt);
        return DateFormat('MMMM yyyy').format(dt);
      }
    }
    if (salary['salaryMonth'] != null) return salary['salaryMonth'].toString();
    return DateFormat('MMMM yyyy').format(DateTime.now());
  }

  String _resolveStatus(dynamic salary) {
    if (salary is! Map) return 'Pending';
    if (salary['isPaid'] == true ||
        salary['status']?.toString().toLowerCase() == 'paid' ||
        salary['status']?.toString().toLowerCase() == 'processed') {
      return 'Paid';
    }
    return 'Pending';
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.payments_outlined, size: 44, color: Color(0xFF10B981)),
          ),
          const SizedBox(height: 20),
          Text('No Salary Records',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.txtPrimary)),
          const SizedBox(height: 8),
          Text('Salary records will appear here\nonce payroll is processed.',
              textAlign: TextAlign.center, style: TextStyle(color: context.txtMuted, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              ref.invalidate(allSalaryProvider);
              ref.read(employeeProvider.notifier).loadEmployees();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    final formatter = NumberFormat('#,##,###', 'en_IN');
    return formatter.format(amount);
  }
}

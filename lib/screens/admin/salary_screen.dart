import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/employee_provider.dart';
import '../../providers/theme_provider.dart';

class AdminSalaryScreen extends ConsumerWidget {
  const AdminSalaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salaryAsync = ref.watch(allSalaryProvider);
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Salary Management',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
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
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF6366F1),
            ),
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.txtMuted),
            onPressed: () => ref.refresh(allSalaryProvider),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: context.mainBgGradient),
        child: SafeArea(
          child: salaryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => _buildEmptyState(context, ref),
            data: (salaries) {
              if (salaries.isEmpty) return _buildEmptyState(context, ref);
              return _buildContent(context, ref, salaries);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, List<dynamic> salaries) {
    // Summary stats
    double totalPayroll = 0;
    int processedCount = 0;
    for (final s in salaries) {
      if (s is Map) {
        final net = double.tryParse(s['netSalary']?.toString() ?? s['netPay']?.toString() ?? s['net']?.toString() ?? s['amount']?.toString() ?? '0') ?? 0;
        totalPayroll += net;
        if ((s['status']?.toString() ?? '').toLowerCase() == 'processed' ||
            (s['status']?.toString() ?? '').toLowerCase() == 'paid') {
          processedCount++;
        }
      }
    }

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(allSalaryProvider),
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
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹${_formatAmount(totalPayroll)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),
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

            ...salaries.map((s) => _buildSalaryCard(context, s)),
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

  Widget _buildSalaryCard(BuildContext context, dynamic salary) {
    if (salary is! Map) return const SizedBox.shrink();
    final emp = salary['employee'];
    final empName = (emp is Map ? emp['name'] : null) ??
        salary['employeeName']?.toString() ??
        salary['name']?.toString() ??
        'Employee';
    final empEmail = (emp is Map ? emp['email'] : null) ??
        salary['employeeEmail']?.toString() ??
        salary['email']?.toString() ??
        '';
    final dept = (emp is Map ? emp['department'] : null) ??
        salary['department']?.toString() ??
        '';

    final netPay = double.tryParse(salary['netSalary']?.toString() ?? salary['netPay']?.toString() ?? salary['net']?.toString() ?? salary['amount']?.toString() ?? '0') ?? 0;
    final status = salary['status']?.toString() ?? 'Pending';
    final month = salary['month']?.toString() ?? salary['salaryMonth']?.toString() ?? DateFormat('MMM yyyy').format(DateTime.now());

    final statusColor = status.toLowerCase() == 'processed' || status.toLowerCase() == 'paid'
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.12 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              empName.isNotEmpty ? empName[0].toUpperCase() : 'E',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(empName, style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  dept.isNotEmpty ? '$dept • $month' : month,
                  style: TextStyle(color: context.txtMuted, fontSize: 12),
                ),
                if (empEmail.isNotEmpty)
                  Text(empEmail, style: TextStyle(color: context.txtMuted, fontSize: 11), overflow: TextOverflow.ellipsis),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
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
            onPressed: () => ref.refresh(allSalaryProvider),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/theme_provider.dart';

class EmployeeSalaryScreen extends ConsumerWidget {
  const EmployeeSalaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salaryAsync = ref.watch(mySalaryProvider);
    final auth = ref.watch(authProvider);
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Salary',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/employee/dashboard');
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
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: context.mainBgGradient),
        child: SafeArea(
          child: salaryAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (e, _) => _buildEmptyState(context, ref, 'Failed to load salary data'),
            data: (salary) {
              if (salary == null || salary.isEmpty) {
                return _buildEmptyState(context, ref, 'No salary records found');
              }
              return _buildSalaryContent(context, salary, auth);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSalaryContent(BuildContext context, Map<String, dynamic> salary, AuthState auth) {
    final basicSalary = _parseAmount(salary['basicSalary'] ?? salary['basic'] ?? salary['base'] ?? salary['amount'] ?? 0);
    final allowances = _parseAmount(salary['allowances'] ?? salary['totalAllowances'] ?? 0);
    final deductions = _parseAmount(salary['deductions'] ?? salary['totalDeductions'] ?? 0);
    final netPay = _parseAmount(salary['netSalary'] ?? salary['netPay'] ?? salary['net'] ?? (basicSalary + allowances - deductions));
    final month = salary['month']?.toString() ?? salary['salaryMonth']?.toString() ?? DateFormat('MMMM yyyy').format(DateTime.now());
    final status = salary['status']?.toString() ?? 'Processed';

    final empName = auth.user?['name'] ?? 'Employee';
    final designation = auth.user?['designation'] ?? auth.user?['position'] ?? 'Employee';

    return RefreshIndicator(
      onRefresh: () async {},
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Salary Card Hero
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(
                          empName.isNotEmpty ? empName[0].toUpperCase() : 'E',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            empName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            designation,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Net Pay - $month',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_formatAmount(netPay)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Earnings & Deductions
            Text(
              'Salary Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.txtPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),

            // Earnings
            _buildSection(
              context,
              title: 'Earnings',
              icon: Icons.trending_up_rounded,
              iconColor: const Color(0xFF10B981),
              items: [
                _SalaryItem('Basic Salary', basicSalary, const Color(0xFF10B981)),
                if (allowances > 0)
                  _SalaryItem('Allowances', allowances, const Color(0xFF06B6D4)),
                ..._parseBreakdownList(salary['earningsBreakdown'] ?? salary['earnings'] ?? []),
              ],
              total: basicSalary + allowances,
              totalLabel: 'Gross Pay',
              totalColor: const Color(0xFF10B981),
            ),

            const SizedBox(height: 16),

            // Deductions
            if (deductions > 0) ...[
              _buildSection(
                context,
                title: 'Deductions',
                icon: Icons.trending_down_rounded,
                iconColor: const Color(0xFFEF4444),
                items: [
                  _SalaryItem('Total Deductions', deductions, const Color(0xFFEF4444)),
                  ..._parseBreakdownList(salary['deductionsBreakdown'] ?? salary['deductionsList'] ?? []),
                ],
                total: deductions,
                totalLabel: 'Total Deducted',
                totalColor: const Color(0xFFEF4444),
              ),
              const SizedBox(height: 16),
            ],

            // Net Pay Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Net Pay',
                    style: TextStyle(
                      color: context.txtPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '₹${_formatAmount(netPay)}',
                    style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<_SalaryItem> items,
    required double total,
    required String totalLabel,
    required Color totalColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: context.txtPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(color: context.txtSecondary, fontSize: 14),
                    ),
                    Text(
                      '₹${_formatAmount(item.amount)}',
                      style: TextStyle(
                        color: item.color,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )),
          Divider(color: context.dividerCol),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                totalLabel,
                style: TextStyle(
                  color: context.txtPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '₹${_formatAmount(total)}',
                style: TextStyle(
                  color: totalColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.payments_outlined,
              size: 44,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.txtPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Salary records will appear here\nonce payroll is processed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.txtMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => ref.refresh(mySalaryProvider),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  double _parseAmount(dynamic val) {
    if (val == null) return 0.0;
    return double.tryParse(val.toString()) ?? 0.0;
  }

  String _formatAmount(double amount) {
    final formatter = NumberFormat('#,##,###', 'en_IN');
    return formatter.format(amount);
  }

  List<_SalaryItem> _parseBreakdownList(dynamic data) {
    if (data is! List) return [];
    return data.whereType<Map>().map((e) {
      final label = e['name']?.toString() ?? e['label']?.toString() ?? e['type']?.toString() ?? '';
      final amount = double.tryParse(e['amount']?.toString() ?? '0') ?? 0;
      return _SalaryItem(label, amount, const Color(0xFF6366F1));
    }).where((item) => item.label.isNotEmpty).toList();
  }
}

class _SalaryItem {
  final String label;
  final double amount;
  final Color color;
  _SalaryItem(this.label, this.amount, this.color);
}

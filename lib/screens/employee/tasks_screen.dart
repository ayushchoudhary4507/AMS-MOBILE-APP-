import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/employee_provider.dart';

class EmployeeTasksScreen extends ConsumerStatefulWidget {
  const EmployeeTasksScreen({super.key});

  @override
  ConsumerState<EmployeeTasksScreen> createState() => _EmployeeTasksScreenState();
}

class _EmployeeTasksScreenState extends ConsumerState<EmployeeTasksScreen> {
  String _filterStatus = 'All';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(taskProvider.notifier).loadTasks());
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskProvider);

    final filteredTasks = _filterStatus == 'All'
        ? taskState.tasks
        : taskState.tasks.where((t) {
            final s = (t['status'] ?? '').toString().toLowerCase();
            return s == _filterStatus.toLowerCase();
          }).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'My Tasks',
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
              context.go('/employee/dashboard');
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.txtPrimary),
            onPressed: () => ref.read(taskProvider.notifier).loadTasks(),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: context.mainBgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Filter Chips
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Pending', 'In Progress', 'Completed'].map((status) {
                      final isSelected = _filterStatus == status;
                      Color chipColor;
                      switch (status) {
                        case 'Pending':
                          chipColor = const Color(0xFFF59E0B);
                          break;
                        case 'In Progress':
                          chipColor = const Color(0xFF6366F1);
                          break;
                        case 'Completed':
                          chipColor = const Color(0xFF10B981);
                          break;
                        default:
                          chipColor = AppColors.primary;
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(status),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _filterStatus = status),
                          selectedColor: chipColor,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : context.txtSecondary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                            fontSize: 13,
                          ),
                          backgroundColor: context.chipBg,
                          side: BorderSide(
                            color: isSelected ? chipColor : context.borderCol,
                          ),
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Stats Row
              if (taskState.tasks.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      _buildStatChip(context, 'Total', taskState.tasks.length.toString(), AppColors.primary),
                      const SizedBox(width: 8),
                      _buildStatChip(context, 'Done',
                          taskState.tasks.where((t) => (t['status'] ?? '').toString().toLowerCase() == 'completed').length.toString(),
                          const Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      _buildStatChip(context, 'Pending',
                          taskState.tasks.where((t) => (t['status'] ?? '').toString().toLowerCase() == 'pending').length.toString(),
                          const Color(0xFFF59E0B)),
                    ],
                  ),
                ),
              ],

              // Tasks List
              Expanded(
                child: taskState.isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : filteredTasks.isEmpty
                        ? _buildEmptyState(context, ref)
                        : RefreshIndicator(
                            onRefresh: () => ref.read(taskProvider.notifier).loadTasks(),
                            color: AppColors.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: filteredTasks.length,
                              itemBuilder: (ctx, i) => _buildTaskCard(context, filteredTasks[i]),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, dynamic task) {
    final title = task['title']?.toString() ?? task['name']?.toString() ?? 'Untitled Task';
    final description = task['description']?.toString() ?? task['details']?.toString() ?? '';
    final status = task['status']?.toString() ?? 'Pending';
    final priority = task['priority']?.toString() ?? 'Normal';
    final dueDate = task['dueDate'] ?? task['deadline'] ?? task['due_date'];
    final projectName = task['project']?['name']?.toString() ?? task['projectName']?.toString() ?? '';

    final statusColor = _getStatusColor(status);
    final priorityColor = _getPriorityColor(priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4, right: 10),
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.txtPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (projectName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        projectName,
                        style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(color: context.txtSecondary, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$priority Priority',
                  style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
              if (dueDate != null) ...[
                const SizedBox(width: 10),
                Icon(Icons.schedule_rounded, size: 13, color: context.txtMuted),
                const SizedBox(width: 4),
                Text(
                  _formatDueDate(dueDate),
                  style: TextStyle(color: context.txtMuted, fontSize: 11),
                ),
              ],
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
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_outlined, size: 44, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text(
            _filterStatus == 'All' ? 'No Tasks Assigned' : 'No $_filterStatus Tasks',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.txtPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tasks assigned to you will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.txtMuted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => ref.read(taskProvider.notifier).loadTasks(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'in progress':
      case 'inprogress':
        return const Color(0xFF6366F1);
      case 'pending':
        return const Color(0xFFF59E0B);
      default:
        return AppColors.primary;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'urgent':
        return const Color(0xFFEF4444);
      case 'medium':
      case 'normal':
        return const Color(0xFFF59E0B);
      case 'low':
        return const Color(0xFF10B981);
      default:
        return AppColors.primary;
    }
  }

  String _formatDueDate(dynamic raw) {
    try {
      final dt = DateTime.parse(raw.toString());
      return DateFormat('d MMM yyyy').format(dt);
    } catch (_) {
      return raw.toString();
    }
  }
}

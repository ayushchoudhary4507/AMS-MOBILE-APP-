import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_provider.dart';

class AdminProjectsScreen extends ConsumerStatefulWidget {
  const AdminProjectsScreen({super.key});

  @override
  ConsumerState<AdminProjectsScreen> createState() => _AdminProjectsScreenState();
}

class _AdminProjectsScreenState extends ConsumerState<AdminProjectsScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Projects',
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
              final auth = ref.read(authProvider);
              if (auth.isAdmin) {
                context.go('/admin/dashboard');
              } else {
                context.go('/employee/dashboard');
              }
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.txtPrimary),
            onPressed: () => ref.refresh(projectsProvider),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: context.mainBgGradient),
        child: SafeArea(
          child: projectsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => _buildEmptyState(context, ref),
            data: (projects) {
              if (projects.isEmpty) return _buildEmptyState(context, ref);
              final filtered = _filter == 'All'
                  ? projects
                  : projects.where((p) => (p['status'] ?? '').toString().toLowerCase() == _filter.toLowerCase()).toList();
              return Column(
                children: [
                  // Filter bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: ['All', 'Active', 'In Progress', 'Completed', 'On Hold', 'Planning'].map((f) {
                          final isSelected = _filter.toLowerCase() == f.toLowerCase() ||
                              (_filter == 'Active' && f == 'In Progress');
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => setState(() => _filter = f),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF6366F1) : context.cardBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF6366F1)
                                          : context.borderCol.withValues(alpha: 0.6),
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    f,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : context.txtSecondary,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async => ref.refresh(projectsProvider),
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _buildProjectCard(context, filtered[i]),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, dynamic project) {
    if (project is! Map) return const SizedBox.shrink();
    final name = project['name']?.toString() ?? project['title']?.toString() ?? 'Unnamed Project';
    final description = project['description']?.toString() ?? '';
    final status = project['status']?.toString() ?? 'Active';
    final endDate = project['endDate'] ?? project['end_date'] ?? project['deadline'] ?? project['startDate'];
    final teamSize = project['team']?.length ?? project['teamSize'] ?? project['members']?.length ?? 0;
    final progress = int.tryParse(project['progress']?.toString() ?? project['completion']?.toString() ?? '0') ?? 0;
    final budget = project['budget']?.toString() ?? project['totalBudget']?.toString() ?? '';

    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderCol.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.04),
            blurRadius: 12,
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6366F1).withValues(alpha: 0.25),
                      const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(Icons.folder_rounded, color: Color(0xFF818CF8), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: context.txtPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(color: context.txtSecondary, fontSize: 12, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),

          if (progress > 0) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Progress', style: TextStyle(color: context.txtMuted, fontSize: 12)),
                Text('$progress%', style: TextStyle(color: context.txtPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress / 100,
                backgroundColor: context.borderCol.withValues(alpha: 0.4),
                valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(progress)),
                minHeight: 6,
              ),
            ),
          ],

          const SizedBox(height: 12),
          Divider(color: context.dividerCol, height: 1),
          const SizedBox(height: 10),

          Row(
            children: [
              if (teamSize > 0) ...[
                Icon(Icons.people_outline_rounded, size: 15, color: context.txtMuted),
                const SizedBox(width: 4),
                Text('$teamSize members', style: TextStyle(color: context.txtMuted, fontSize: 12)),
                const SizedBox(width: 16),
              ],
              if (endDate != null) ...[
                Icon(Icons.schedule_rounded, size: 15, color: context.txtMuted),
                const SizedBox(width: 4),
                Text(_formatDate(endDate), style: TextStyle(color: context.txtMuted, fontSize: 12)),
              ],
              const Spacer(),
              if (budget.isNotEmpty)
                Text(
                  '₹$budget',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.folder_open_outlined, size: 44, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text('No Projects Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.txtPrimary)),
          const SizedBox(height: 8),
          Text('Projects will appear here once created.',
              textAlign: TextAlign.center, style: TextStyle(color: context.txtMuted, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => ref.refresh(projectsProvider),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'in progress':
        return const Color(0xFF10B981);
      case 'completed':
        return const Color(0xFF6366F1);
      case 'on hold':
        return const Color(0xFFF59E0B);
      case 'planning':
        return const Color(0xFF06B6D4);
      default:
        return AppColors.primary;
    }
  }

  Color _getProgressColor(int progress) {
    if (progress >= 80) return const Color(0xFF10B981);
    if (progress >= 50) return const Color(0xFF6366F1);
    if (progress >= 25) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _formatDate(dynamic raw) {
    try {
      return DateFormat('d MMM yyyy').format(DateTime.parse(raw.toString()));
    } catch (_) {
      return raw.toString();
    }
  }
}

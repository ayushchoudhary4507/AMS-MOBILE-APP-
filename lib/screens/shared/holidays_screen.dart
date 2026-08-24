import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/employee_provider.dart';

class HolidaysScreen extends ConsumerWidget {
  const HolidaysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holidaysAsync = ref.watch(holidaysProvider);
    final now = DateTime.now();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Holidays Calendar',
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
            onPressed: () => ref.refresh(holidaysProvider),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: context.mainBgGradient),
        child: SafeArea(
          child: holidaysAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (e, _) => _buildEmptyState(context, ref),
            data: (holidays) {
              if (holidays.isEmpty) {
                return _buildEmptyState(context, ref);
              }

              // Sort by date
              final sorted = List.from(holidays);
              sorted.sort((a, b) {
                try {
                  final da = DateTime.parse(a['date']?.toString() ?? '');
                  final db = DateTime.parse(b['date']?.toString() ?? '');
                  return da.compareTo(db);
                } catch (_) {
                  return 0;
                }
              });

              // Upcoming vs Past
              final upcoming = sorted.where((h) {
                try {
                  final d = DateTime.parse(h['date']?.toString() ?? '');
                  return d.isAfter(now.subtract(const Duration(days: 1)));
                } catch (_) {
                  return true;
                }
              }).toList();

              final past = sorted.where((h) {
                try {
                  final d = DateTime.parse(h['date']?.toString() ?? '');
                  return d.isBefore(now.subtract(const Duration(days: 1)));
                } catch (_) {
                  return false;
                }
              }).toList();

              return RefreshIndicator(
                onRefresh: () async => ref.refresh(holidaysProvider),
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Year Header
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Public Holidays',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  now.year.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${holidays.length} holidays this year',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.holiday_village_rounded,
                              color: Colors.white54,
                              size: 60,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Upcoming Holidays
                      if (upcoming.isNotEmpty) ...[
                        Text(
                          'Upcoming Holidays',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.txtPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...upcoming.map((h) => _buildHolidayCard(context, h, now, isUpcoming: true)),
                        const SizedBox(height: 24),
                      ],

                      // Past Holidays
                      if (past.isNotEmpty) ...[
                        Text(
                          'Past Holidays',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.txtSecondary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...past.reversed.map((h) => _buildHolidayCard(context, h, now, isUpcoming: false)),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHolidayCard(BuildContext context, dynamic holiday, DateTime now, {required bool isUpcoming}) {
    final name = holiday['name']?.toString() ?? holiday['title']?.toString() ?? 'Holiday';
    final description = holiday['description']?.toString() ?? holiday['reason']?.toString() ?? '';
    final type = holiday['type']?.toString() ?? holiday['category']?.toString() ?? 'National';
    final dateRaw = holiday['date'];

    DateTime? date;
    String dayStr = '';
    try {
      date = DateTime.parse(dateRaw.toString());
      dayStr = DateFormat('EEEE').format(date);
    } catch (_) {
      // ignore parse error
    }

    final isToday = date != null &&
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    final typeColor = _getTypeColor(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isToday
            ? const Color(0xFF6366F1).withValues(alpha: 0.08)
            : context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isToday
              ? const Color(0xFF6366F1).withValues(alpha: 0.5)
              : isUpcoming
                  ? context.borderCol.withValues(alpha: 0.8)
                  : context.borderCol.withValues(alpha: 0.4),
          width: isToday ? 1.5 : 1,
        ),
        boxShadow: isUpcoming
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: context.isDark ? 0.16 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          // Date Block
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: isUpcoming
                  ? LinearGradient(
                      colors: [
                        const Color(0xFF6366F1).withValues(alpha: 0.22),
                        const Color(0xFF818CF8).withValues(alpha: 0.12),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isUpcoming ? null : context.cardLightBg,
              borderRadius: BorderRadius.circular(14),
              border: isUpcoming
                  ? Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3))
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  date != null ? date.day.toString() : '--',
                  style: TextStyle(
                    color: isUpcoming ? const Color(0xFF818CF8) : context.txtMuted,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  date != null ? DateFormat('MMM').format(date).toUpperCase() : '',
                  style: TextStyle(
                    color: isUpcoming
                        ? const Color(0xFF6366F1)
                        : context.txtMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
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
                          color: isUpcoming ? context.txtPrimary : context.txtSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'TODAY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (dayStr.isNotEmpty) ...[
                      Text(
                        dayStr,
                        style: TextStyle(color: context.txtMuted, fontSize: 12),
                      ),
                      Text(
                        '  •  ',
                        style: TextStyle(color: context.txtMuted, fontSize: 12),
                      ),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: typeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(color: context.txtMuted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
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
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.holiday_village_outlined, size: 44, color: Color(0xFF6366F1)),
          ),
          const SizedBox(height: 20),
          Text(
            'No Holidays Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.txtPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Holiday calendar will appear\nhere once configured.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.txtMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => ref.refresh(holidaysProvider),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'public':
      case 'national':
        return const Color(0xFF6366F1); // Brand Indigo
      case 'company':
        return const Color(0xFF10B981); // Emerald Green
      case 'optional':
        return const Color(0xFFF59E0B); // Amber
      case 'regional':
        return const Color(0xFF06B6D4); // Cyan
      case 'festival':
        return const Color(0xFF8B5CF6); // Purple
      default:
        return const Color(0xFF6366F1);
    }
  }
}

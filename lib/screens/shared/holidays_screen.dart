import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/employee_service.dart';

class HolidaysScreen extends ConsumerStatefulWidget {
  const HolidaysScreen({super.key});

  @override
  ConsumerState<HolidaysScreen> createState() => _HolidaysScreenState();
}

class _HolidaysScreenState extends ConsumerState<HolidaysScreen> {
  int _selectedYear = DateTime.now().year;
  bool _isLoading = false;
  List<dynamic> _holidays = [];
  int _activeViewTab = 0; // 0: 12-Month Calendar Grid, 1: Upcoming List

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchHolidays();
    });
  }

  Future<void> _fetchHolidays() async {
    setState(() => _isLoading = true);
    try {
      final res = await HolidayService.getAll(year: _selectedYear);
      final list = res['data'] ?? res['holidays'] ?? [];
      if (mounted) {
        setState(() {
          _holidays = list is List ? list : [];
        });
      }
    } catch (_) {
      if (mounted) setState(() => _holidays = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── ADD / EDIT HOLIDAY MODAL (Matching Website Holidays.jsx) ───────────────
  void _showHolidayModal({dynamic existingHoliday, DateTime? preselectedDate}) {
    final isEdit = existingHoliday != null;
    final nameCtrl = TextEditingController(text: existingHoliday?['name']?.toString() ?? '');
    final descCtrl = TextEditingController(text: existingHoliday?['description']?.toString() ?? '');
    String selectedType = existingHoliday?['type']?.toString() ?? 'company';
    bool isRecurring = existingHoliday?['recurring'] == true;

    DateTime initialDate = preselectedDate ?? DateTime.now();
    if (existingHoliday?['date'] != null) {
      try {
        initialDate = DateTime.parse(existingHoliday['date'].toString());
      } catch (_) {}
    }
    DateTime chosenDate = initialDate;

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
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.celebration_rounded, color: Color(0xFF6366F1), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isEdit ? 'Edit Holiday' : 'Add Holiday',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.txtPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Date Picker Box
                    Text('Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.txtPrimary)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: chosenDate,
                          firstDate: DateTime(_selectedYear - 2),
                          lastDate: DateTime(_selectedYear + 3),
                        );
                        if (picked != null) {
                          setModalState(() => chosenDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: context.borderCol),
                          borderRadius: BorderRadius.circular(12),
                          color: context.isDark ? const Color(0xFF13162A) : const Color(0xFFF8FAFC),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF6366F1)),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('yyyy-MM-dd (EEEE)').format(chosenDate),
                              style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w600, fontSize: 13.5),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_drop_down_rounded),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Holiday Name
                    Text('Holiday Name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.txtPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Diwali, Independence Day',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: context.isDark ? const Color(0xFF13162A) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Type Dropdown
                    Text('Type *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.txtPrimary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: context.isDark ? const Color(0xFF13162A) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      dropdownColor: context.cardBg,
                      items: const [
                        DropdownMenuItem(value: 'company', child: Text('🏢 Company Holiday')),
                        DropdownMenuItem(value: 'public', child: Text('🏛️ Public Holiday')),
                        DropdownMenuItem(value: 'optional', child: Text('✨ Optional Holiday')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Description
                    Text('Description (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.txtPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      decoration: InputDecoration(
                        hintText: 'Optional description or notes',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: context.isDark ? const Color(0xFF13162A) : const Color(0xFFF8FAFC),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),

                    // Recurring checkbox
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Recurring (repeats every year)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.txtPrimary)),
                      value: isRecurring,
                      activeThumbColor: const Color(0xFF6366F1),
                      onChanged: (val) => setModalState(() => isRecurring = val),
                    ),
                    const SizedBox(height: 16),

                    // Actions Row
                    Row(
                      children: [
                        if (isEdit) ...[
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                side: const BorderSide(color: Color(0xFFEF4444)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                final id = existingHoliday['_id']?.toString() ?? '';
                                final name = existingHoliday['name']?.toString() ?? 'Holiday';
                                _handleDeleteHoliday(id, name);
                              },
                              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () async {
                              final sm = ScaffoldMessenger.of(context);
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) {
                                sm.showSnackBar(const SnackBar(content: Text('Please enter holiday name')));
                                return;
                              }

                              Navigator.pop(ctx);
                              setState(() => _isLoading = true);

                              final payload = {
                                'name': name,
                                'date': chosenDate.toIso8601String(),
                                'type': selectedType,
                                'description': descCtrl.text.trim(),
                                'recurring': isRecurring,
                              };

                              try {
                                if (isEdit) {
                                  final id = existingHoliday['_id']?.toString() ?? '';
                                  await HolidayService.updateHoliday(id, payload);
                                  sm.showSnackBar(const SnackBar(content: Text('Holiday updated successfully! ✓'), backgroundColor: Color(0xFF10B981)));
                                } else {
                                  await HolidayService.createHoliday(payload);
                                  sm.showSnackBar(const SnackBar(content: Text('Holiday added successfully! ✓'), backgroundColor: Color(0xFF10B981)));
                                }
                                _fetchHolidays();
                              } catch (e) {
                                sm.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                              } finally {
                                if (mounted) setState(() => _isLoading = false);
                              }
                            },
                            child: Text(isEdit ? 'Update' : 'Add Holiday', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
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

  // ── IMPORT PUBLIC HOLIDAYS (Matching Website Holidays.jsx) ──────────────────
  Future<void> _handleImportHolidays() async {
    final sm = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text('Import Public Holidays', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.bold)),
        content: Text('This will import common public holidays for $_selectedYear. Continue?', style: TextStyle(color: context.txtSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import Now'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final res = await HolidayService.importHolidays(_selectedYear);
      if (!mounted) return;
      if (res['success'] == true) {
        sm.showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Holidays imported successfully! ✓'), backgroundColor: const Color(0xFF10B981)));
        _fetchHolidays();
      } else {
        sm.showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Failed to import holidays'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      sm.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── DELETE HOLIDAY ──────────────────────────────────────────────────────────
  Future<void> _handleDeleteHoliday(String id, String name) async {
    final sm = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text('Delete Holiday', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this holiday?', style: TextStyle(color: context.txtSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await HolidayService.deleteHoliday(id);
      if (!mounted) return;
      sm.showSnackBar(const SnackBar(content: Text('Holiday deleted successfully ✓'), backgroundColor: Color(0xFF10B981)));
      _fetchHolidays();
    } catch (e) {
      if (!mounted) return;
      sm.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isAdmin = auth.isAdmin;
    final now = DateTime.now();

    // Chronologically sorted
    final sortedHolidays = List.from(_holidays);
    sortedHolidays.sort((a, b) {
      try {
        final da = DateTime.parse(a['date']?.toString() ?? '');
        final db = DateTime.parse(b['date']?.toString() ?? '');
        return da.compareTo(db);
      } catch (_) {
        return 0;
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Holiday Calendar',
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
              context.go(isAdmin ? '/admin/dashboard' : '/employee/dashboard');
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.txtPrimary),
            tooltip: 'Refresh',
            onPressed: _fetchHolidays,
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
            onRefresh: _fetchHolidays,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Year Header & Controls Bar (Exact Website Parity - Overflow proof)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        // Year Select
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.borderCol),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_rounded, color: Color(0xFF6366F1), size: 15),
                              const SizedBox(width: 6),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _selectedYear,
                                  isDense: true,
                                  dropdownColor: context.cardBg,
                                  items: [_selectedYear - 1, _selectedYear, _selectedYear + 1, _selectedYear + 2].map((y) {
                                    return DropdownMenuItem(value: y, child: Text('$y', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.bold, fontSize: 13)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedYear = val);
                                      _fetchHolidays();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isAdmin) ...[
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: context.cardBg,
                              foregroundColor: const Color(0xFF6366F1),
                              side: const BorderSide(color: Color(0xFF6366F1), width: 1.2),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.download_rounded, size: 15),
                            label: const Text('Import', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            onPressed: _handleImportHolidays,
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.add_rounded, size: 15),
                            label: const Text('Add Holiday', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            onPressed: () => _showHolidayModal(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // View Mode Tabs (12-Month Calendar Grid vs Upcoming List)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderCol),
                    ),
                    child: Row(
                      children: [
                        _buildTabButton(0, '12-Month Calendar Grid', Icons.calendar_month_rounded),
                        _buildTabButton(1, 'Upcoming List (${_holidays.length})', Icons.list_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Content View
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    )
                  else if (_activeViewTab == 0)
                    _buildCalendarGridView(sortedHolidays, isAdmin)
                  else
                    _buildUpcomingListView(sortedHolidays, isAdmin, now),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSel = _activeViewTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeViewTab = index),
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
              Text(
                label,
                style: TextStyle(
                  color: isSel ? Colors.white : context.txtSecondary,
                  fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. 12-MONTH CALENDAR GRID VIEW (Full Website Parity) ──────────────────
  Widget _buildCalendarGridView(List<dynamic> holidays, bool isAdmin) {
    // Map dates to holiday
    final Map<String, dynamic> holidayDateMap = {};
    for (final h in holidays) {
      if (h is Map && h['date'] != null) {
        try {
          final d = DateTime.parse(h['date'].toString());
          final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          holidayDateMap[key] = h;
        } catch (_) {}
      }
    }

    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Column(
      children: List.generate(12, (mIdx) {
        final month = mIdx + 1;
        final monthName = monthNames[mIdx];
        final firstDay = DateTime(_selectedYear, month, 1);
        final lastDay = DateTime(_selectedYear, month + 1, 0);
        final daysInMonth = lastDay.day;
        final startingDay = firstDay.weekday % 7; // Sunday = 0

        // Month holidays count
        final monthHolidays = holidays.where((h) {
          if (h is! Map || h['date'] == null) return false;
          try {
            final d = DateTime.parse(h['date'].toString());
            return d.year == _selectedYear && d.month == month;
          } catch (_) {
            return false;
          }
        }).toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderCol),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: context.isDark ? 0.15 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month Title & Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$monthName $_selectedYear',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: context.txtPrimary),
                  ),
                  if (monthHolidays.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${monthHolidays.length} holiday${monthHolidays.length > 1 ? 's' : ''}',
                        style: const TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Weekday Headers (Sun, Mon, Tue, Wed, Thu, Fri, Sat)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((w) {
                  return SizedBox(
                    width: 36,
                    child: Center(
                      child: Text(w, style: TextStyle(color: context.txtMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),

              // Days Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: startingDay + daysInMonth,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (ctx, idx) {
                  if (idx < startingDay) return const SizedBox.shrink();
                  final day = idx - startingDay + 1;
                  final key = '$_selectedYear-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                  final holiday = holidayDateMap[key];
                  final cellDate = DateTime(_selectedYear, month, day);

                  final isHoliday = holiday != null;
                  final isPublic = isHoliday && (holiday['type'] ?? '').toString().toLowerCase() == 'public';

                  return InkWell(
                    onTap: () {
                      if (isAdmin) {
                        _showHolidayModal(existingHoliday: holiday, preselectedDate: cellDate);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isHoliday
                            ? (isPublic ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFF6366F1).withValues(alpha: 0.15))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isHoliday
                            ? Border.all(color: isPublic ? const Color(0xFF10B981) : const Color(0xFF6366F1), width: 1.2)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isHoliday ? FontWeight.w900 : FontWeight.w500,
                              color: isHoliday ? (isPublic ? const Color(0xFF10B981) : const Color(0xFF6366F1)) : context.txtPrimary,
                            ),
                          ),
                          if (isHoliday)
                            Text(
                              isPublic ? '🏛️' : '🏢',
                              style: const TextStyle(fontSize: 8.5),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Holiday names in month footer
              if (monthHolidays.isNotEmpty) ...[
                const SizedBox(height: 10),
                Divider(color: context.borderCol.withValues(alpha: 0.4), height: 1),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: monthHolidays.map((h) {
                    final name = (h['name'] ?? 'Holiday').toString();
                    final type = (h['type'] ?? 'company').toString().toLowerCase();
                    final isPublic = type == 'public';

                    return InkWell(
                      onTap: isAdmin ? () => _showHolidayModal(existingHoliday: h) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isPublic ? const Color(0xFF10B981) : const Color(0xFF6366F1)).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: (isPublic ? const Color(0xFF10B981) : const Color(0xFF6366F1)).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(isPublic ? '🏛️ ' : '🏢 ', style: const TextStyle(fontSize: 10)),
                            Text(
                              name,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isPublic ? const Color(0xFF10B981) : const Color(0xFF6366F1)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  // ── 2. UPCOMING LIST VIEW ──────────────────────────────────────────────────
  Widget _buildUpcomingListView(List<dynamic> holidays, bool isAdmin, DateTime now) {
    if (holidays.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderCol),
        ),
        child: Column(
          children: [
            Icon(Icons.event_busy_outlined, size: 48, color: context.txtMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('No holidays configured for $_selectedYear', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.txtPrimary)),
            const SizedBox(height: 6),
            Text('Tap "Import Holidays" or "Add Holiday" to configure holidays.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: context.txtMuted)),
          ],
        ),
      );
    }

    return Column(
      children: holidays.map((h) {
        if (h is! Map) return const SizedBox.shrink();
        final id = h['_id']?.toString() ?? '';
        final name = (h['name'] ?? 'Holiday').toString();
        final desc = (h['description'] ?? '').toString();
        final type = (h['type'] ?? 'company').toString().toLowerCase();

        DateTime? date;
        try {
          date = DateTime.parse(h['date'].toString());
        } catch (_) {}

        String countdownText = '';
        Color countdownColor = const Color(0xFF6366F1);
        if (date != null) {
          final diff = DateTime(date.year, date.month, date.day).difference(DateTime(now.year, now.month, now.day)).inDays;
          if (diff == 0) {
            countdownText = 'Today 🎉';
            countdownColor = const Color(0xFF10B981);
          } else if (diff == 1) {
            countdownText = 'Tomorrow';
            countdownColor = const Color(0xFF10B981);
          } else if (diff > 1) {
            countdownText = 'In $diff days';
            countdownColor = const Color(0xFF6366F1);
          } else {
            countdownText = 'Past';
            countdownColor = context.txtMuted;
          }
        }

        Color typeBg = const Color(0xFF6366F1).withValues(alpha: 0.12);
        Color typeText = const Color(0xFF6366F1);
        if (type == 'public') {
          typeBg = const Color(0xFF10B981).withValues(alpha: 0.12);
          typeText = const Color(0xFF10B981);
        } else if (type == 'optional') {
          typeBg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
          typeText = const Color(0xFFF59E0B);
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
              // Date Box
              Container(
                width: 48,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      date != null ? DateFormat('MMM').format(date).toUpperCase() : 'HOL',
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      date != null ? '${date.day}' : '•',
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Title & Type
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            type.toUpperCase(),
                            style: TextStyle(color: typeText, fontSize: 9.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              desc,
                              style: TextStyle(color: context.txtMuted, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Countdown / Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: countdownColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      countdownText,
                      style: TextStyle(color: countdownColor, fontSize: 10.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (isAdmin)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF6366F1)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () => _showHolidayModal(existingHoliday: h),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () => _handleDeleteHoliday(id, name),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

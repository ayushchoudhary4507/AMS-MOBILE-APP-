import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_provider.dart';
import '../../services/employee_service.dart';

class AdminShiftsScreen extends ConsumerStatefulWidget {
  const AdminShiftsScreen({super.key});

  @override
  ConsumerState<AdminShiftsScreen> createState() => _AdminShiftsScreenState();
}

class _AdminShiftsScreenState extends ConsumerState<AdminShiftsScreen> {
  int _activeTab = 0; // 0: Shifts, 1: Assignments
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    ref.invalidate(shiftsProvider);
    ref.invalidate(shiftAssignmentsProvider);
    await Future.wait([
      ref.read(employeeProvider.notifier).loadEmployees(),
    ]);
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 'N/A';
    try {
      final parts = timeStr.split(':').map(int.parse).toList();
      if (parts.length >= 2) {
        final hours = parts[0];
        final minutes = parts[1];
        final period = hours >= 12 ? 'PM' : 'AM';
        final displayHours = hours % 12 == 0 ? 12 : hours % 12;
        return '$displayHours:${minutes.toString().padLeft(2, '0')} $period';
      }
    } catch (_) {}
    return timeStr;
  }

  Color _getShiftColor(String shiftName) {
    final lower = shiftName.toLowerCase();
    if (lower.contains('morning')) return const Color(0xFF10B981);
    if (lower.contains('evening')) return const Color(0xFF8B5CF6);
    if (lower.contains('night')) return const Color(0xFF6366F1);
    if (lower.contains('flex')) return const Color(0xFF06B6D4);
    return const Color(0xFFF59E0B);
  }

  // ── CREATE SHIFT MODAL ──────────────────────────────────────────────────────
  void _showCreateShiftModal(BuildContext context) {
    final nameCtrl = TextEditingController(text: 'Morning');
    final startCtrl = TextEditingController(text: '09:00');
    final endCtrl = TextEditingController(text: '17:00');
    final descCtrl = TextEditingController();
    String selectedPreset = 'Morning';

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
                          child: const Icon(Icons.access_time_rounded, color: Color(0xFF6366F1), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Create New Shift',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.txtPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Presets
                    Text('Quick Presets', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.txtSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ('Morning', '09:00', '17:00'),
                        ('Evening', '14:00', '22:00'),
                        ('Night', '22:00', '06:00'),
                        ('Flexible', '10:00', '18:00'),
                      ].map((preset) {
                        final isSel = selectedPreset == preset.$1;
                        return ChoiceChip(
                          label: Text(preset.$1),
                          selected: isSel,
                          selectedColor: const Color(0xFF6366F1),
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : context.txtPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (sel) {
                            if (sel) {
                              setModalState(() {
                                selectedPreset = preset.$1;
                                nameCtrl.text = preset.$1;
                                startCtrl.text = preset.$2;
                                endCtrl.text = preset.$3;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Shift Name Field
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Shift Name',
                        prefixIcon: const Icon(Icons.label_outline_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: context.isDark ? const Color(0xFF13162A) : const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Start and End Times
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: startCtrl,
                            decoration: InputDecoration(
                              labelText: 'Start Time (HH:mm)',
                              hintText: '09:00',
                              prefixIcon: const Icon(Icons.schedule_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: context.isDark ? const Color(0xFF13162A) : const Color(0xFFF8FAFC),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: endCtrl,
                            decoration: InputDecoration(
                              labelText: 'End Time (HH:mm)',
                              hintText: '17:00',
                              prefixIcon: const Icon(Icons.alarm_off_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: context.isDark ? const Color(0xFF13162A) : const Color(0xFFF8FAFC),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextField(
                      controller: descCtrl,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        prefixIcon: const Icon(Icons.description_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: context.isDark ? const Color(0xFF13162A) : const Color(0xFFF8FAFC),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isLoading ? null : () async {
                          final name = nameCtrl.text.trim();
                          final start = startCtrl.text.trim();
                          final end = endCtrl.text.trim();
                          final sm = ScaffoldMessenger.of(context);
                          if (name.isEmpty || start.isEmpty || end.isEmpty) {
                            sm.showSnackBar(
                              const SnackBar(content: Text('Please fill all required fields')),
                            );
                            return;
                          }

                          Navigator.pop(ctx);
                          setState(() => _isLoading = true);
                          try {
                            final res = await ShiftService.createShift({
                              'shiftName': name,
                              'startTime': start,
                              'endTime': end,
                              'description': descCtrl.text.trim(),
                            });
                            if (!mounted) return;
                            if (res['success'] == true) {
                              sm.showSnackBar(
                                const SnackBar(content: Text('Shift created successfully! ✓'), backgroundColor: Color(0xFF10B981)),
                              );
                              ref.invalidate(shiftsProvider);
                            } else {
                              sm.showSnackBar(
                                SnackBar(content: Text(res['message']?.toString() ?? 'Failed to create shift'), backgroundColor: Colors.red),
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
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Save Shift Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

  // ── ASSIGN SHIFT MODAL ──────────────────────────────────────────────────────
  void _showAssignShiftModal(BuildContext context, List<dynamic> shifts, List<dynamic> employees) {
    if (shifts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create at least one shift first')),
      );
      return;
    }

    String selectedShiftId = shifts[0]['_id']?.toString() ?? '';
    final List<String> selectedEmployeeIds = [];
    final List<String> selectedDates = [];

    // Next 7 days
    final now = DateTime.now();
    final next7Days = List.generate(7, (i) {
      final d = now.add(Duration(days: i));
      return DateFormat('yyyy-MM-dd').format(d);
    });

    // Default select today
    selectedDates.add(next7Days[0]);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
              padding: const EdgeInsets.all(20),
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
                          child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF10B981), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Assign Shift to Staff',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.txtPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 1. Select Shift
                    Text('Select Shift', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.txtPrimary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: context.borderCol),
                        borderRadius: BorderRadius.circular(12),
                        color: context.isDark ? const Color(0xFF13162A) : const Color(0xFFF8FAFC),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedShiftId,
                          isExpanded: true,
                          dropdownColor: context.cardBg,
                          items: shifts.map((s) {
                            final id = s['_id']?.toString() ?? '';
                            final name = s['shiftName']?.toString() ?? 'Shift';
                            final time = '${_formatTime(s['startTime'])} - ${_formatTime(s['endTime'])}';
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text('$name ($time)', style: TextStyle(color: context.txtPrimary, fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedShiftId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Select Dates
                    Text('Select Dates (Next 7 Days)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.txtPrimary)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: next7Days.map((dStr) {
                          final isSel = selectedDates.contains(dStr);
                          final dt = DateTime.parse(dStr);
                          final dayName = DateFormat('E').format(dt);
                          final dayNum = DateFormat('dd MMM').format(dt);

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text('$dayName\n$dayNum', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSel ? Colors.white : context.txtPrimary)),
                              selected: isSel,
                              selectedColor: const Color(0xFF10B981),
                              onSelected: (sel) {
                                setModalState(() {
                                  if (sel) {
                                    selectedDates.add(dStr);
                                  } else {
                                    selectedDates.remove(dStr);
                                  }
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Select Employees
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Select Employees', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.txtPrimary)),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              if (selectedEmployeeIds.length == employees.length) {
                                selectedEmployeeIds.clear();
                              } else {
                                selectedEmployeeIds.clear();
                                for (var e in employees) {
                                  final id = (e['_id'] ?? e['id'])?.toString();
                                  if (id != null) selectedEmployeeIds.add(id);
                                }
                              }
                            });
                          },
                          child: Text(selectedEmployeeIds.length == employees.length ? 'Deselect All' : 'Select All', style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        border: Border.all(color: context.borderCol),
                        borderRadius: BorderRadius.circular(12),
                        color: context.isDark ? const Color(0xFF13162A) : const Color(0xFFF8FAFC),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: employees.length,
                        itemBuilder: (ctx, idx) {
                          final emp = employees[idx];
                          final id = (emp['_id'] ?? emp['id'])?.toString() ?? '';
                          final name = (emp['name'] ?? 'Staff Member').toString();
                          final dept = (emp['department'] ?? 'General').toString();
                          final isSel = selectedEmployeeIds.contains(id);

                          return CheckboxListTile(
                            dense: true,
                            value: isSel,
                            title: Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.txtPrimary)),
                            subtitle: Text(dept, style: TextStyle(fontSize: 11, color: context.txtMuted)),
                            activeColor: const Color(0xFF10B981),
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  selectedEmployeeIds.add(id);
                                } else {
                                  selectedEmployeeIds.remove(id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isLoading ? null : () async {
                          final sm = ScaffoldMessenger.of(context);
                          if (selectedEmployeeIds.isEmpty) {
                            sm.showSnackBar(
                              const SnackBar(content: Text('Please select at least one employee')),
                            );
                            return;
                          }
                          if (selectedDates.isEmpty) {
                            sm.showSnackBar(
                              const SnackBar(content: Text('Please select at least one date')),
                            );
                            return;
                          }

                          Navigator.pop(ctx);
                          setState(() => _isLoading = true);
                          try {
                            final res = await ShiftService.assignShift({
                              'shiftId': selectedShiftId,
                              'employeeIds': selectedEmployeeIds,
                              'dates': selectedDates,
                            });
                            if (!mounted) return;
                            if (res['success'] == true) {
                              sm.showSnackBar(
                                SnackBar(content: Text(res['message']?.toString() ?? 'Shift assigned successfully! ✓'), backgroundColor: const Color(0xFF10B981)),
                              );
                              ref.invalidate(shiftAssignmentsProvider);
                              setState(() => _activeTab = 1); // switch to assignments tab
                            } else {
                              sm.showSnackBar(
                                SnackBar(content: Text(res['message']?.toString() ?? 'Failed to assign shift'), backgroundColor: Colors.red),
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
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Confirm Shift Assignment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

  // ── DELETE SHIFT HANDLER ────────────────────────────────────────────────────
  Future<void> _handleDeleteShift(String id, String name) async {
    final sm = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text('Delete Shift', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete shift "$name"?', style: TextStyle(color: context.txtSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final res = await ShiftService.deleteShift(id);
      if (!mounted) return;
      if (res['success'] == true) {
        sm.showSnackBar(
          const SnackBar(content: Text('Shift deleted successfully ✓'), backgroundColor: Color(0xFF10B981)),
        );
        ref.invalidate(shiftsProvider);
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

  // ── REMOVE ASSIGNMENT HANDLER ───────────────────────────────────────────────
  Future<void> _handleRemoveAssignment(String id) async {
    final sm = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text('Remove Assignment', style: TextStyle(color: context.txtPrimary, fontWeight: FontWeight.bold)),
        content: const Text('Remove this shift assignment?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final res = await ShiftService.removeAssignment(id);
      if (!mounted) return;
      if (res['success'] == true) {
        sm.showSnackBar(
          const SnackBar(content: Text('Assignment removed ✓'), backgroundColor: Color(0xFF10B981)),
        );
        ref.invalidate(shiftAssignmentsProvider);
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
    final shiftsAsync = ref.watch(shiftsProvider);
    final assignmentsAsync = ref.watch(shiftAssignmentsProvider);
    final employeeState = ref.watch(employeeProvider);
    final employees = employeeState.employees;
    final shifts = shiftsAsync.value ?? [];

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Shift Management',
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
            onPressed: _refreshData,
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
              // Header Banner & Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Create Shift', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            onPressed: () => _showCreateShiftModal(context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: context.cardBg,
                              foregroundColor: const Color(0xFF10B981),
                              side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                            label: const Text('Assign Shift', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            onPressed: () => _showAssignShiftModal(context, shifts, employees),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Tab Switcher (Shifts vs Assignments)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.borderCol),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _activeTab = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _activeTab == 0 ? const Color(0xFF6366F1) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'Configured Shifts (${shifts.length})',
                                    style: TextStyle(
                                      color: _activeTab == 0 ? Colors.white : context.txtSecondary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _activeTab = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _activeTab == 1 ? const Color(0xFF6366F1) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'Assignments (${assignmentsAsync.value?.length ?? 0})',
                                    style: TextStyle(
                                      color: _activeTab == 1 ? Colors.white : context.txtSecondary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Tab View Content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshData,
                  color: AppColors.primary,
                  child: _activeTab == 0
                      ? _buildShiftsTab(context, shiftsAsync)
                      : _buildAssignmentsTab(context, assignmentsAsync),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── TAB 1: SHIFTS LIST ─────────────────────────────────────────────────────
  Widget _buildShiftsTab(BuildContext context, AsyncValue<List<dynamic>> shiftsAsync) {
    return shiftsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: context.txtMuted))),
      data: (shifts) {
        if (shifts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_rounded, size: 48, color: context.txtMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text('No Shifts Created', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.txtPrimary)),
                const SizedBox(height: 4),
                Text('Tap "Create Shift" above to add your first shift schedule.', style: TextStyle(fontSize: 12, color: context.txtMuted)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          itemCount: shifts.length,
          itemBuilder: (ctx, idx) {
            final s = shifts[idx];
            if (s is! Map) return const SizedBox.shrink();
            final id = s['_id']?.toString() ?? '';
            final name = s['shiftName']?.toString() ?? 'Shift';
            final start = _formatTime(s['startTime']?.toString());
            final end = _formatTime(s['endTime']?.toString());
            final desc = s['description']?.toString() ?? '';
            final color = _getShiftColor(name);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: context.isDark ? 0.35 : 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: context.isDark ? 0.08 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        tooltip: 'Delete Shift',
                        onPressed: () => _handleDeleteShift(id, name),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 16, color: context.txtSecondary),
                      const SizedBox(width: 6),
                      Text(
                        '$start  –  $end',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.txtPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      desc,
                      style: TextStyle(fontSize: 12, color: context.txtMuted),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── TAB 2: ASSIGNMENTS LIST ────────────────────────────────────────────────
  Widget _buildAssignmentsTab(BuildContext context, AsyncValue<List<dynamic>> assignmentsAsync) {
    return assignmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: context.txtMuted))),
      data: (assignments) {
        if (assignments.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.assignment_ind_outlined, size: 48, color: context.txtMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text('No Shift Assignments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.txtPrimary)),
                const SizedBox(height: 4),
                Text('Assign staff to shifts using the "Assign Shift" button.', style: TextStyle(fontSize: 12, color: context.txtMuted)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          itemCount: assignments.length,
          itemBuilder: (ctx, idx) {
            final a = assignments[idx];
            if (a is! Map) return const SizedBox.shrink();

            final id = a['_id']?.toString() ?? '';
            final emp = a['employeeId'] ?? a['userId'];
            final empName = emp is Map ? (emp['name'] ?? 'Staff Member') : 'Staff Member';
            final initial = empName.toString().isNotEmpty ? empName.toString()[0].toUpperCase() : 'S';

            final shift = a['shiftId'];
            final shiftName = shift is Map ? (shift['shiftName'] ?? 'General') : 'General';
            final shiftStart = shift is Map ? _formatTime(shift['startTime']?.toString()) : '09:00 AM';
            final shiftEnd = shift is Map ? _formatTime(shift['endTime']?.toString()) : '05:00 PM';
            final color = _getShiftColor(shiftName.toString());

            String dateStr = 'Today';
            if (a['date'] != null) {
              try {
                final d = DateTime.parse(a['date'].toString());
                dateStr = DateFormat('EEE, dd MMM yyyy').format(d);
              } catch (_) {}
            }

            final isNotified = a['isNotified'] == true;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderCol.withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: context.isDark ? 0.15 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.8), color],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          empName.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.txtPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                shiftName.toString(),
                                style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$shiftStart - $shiftEnd',
                              style: TextStyle(fontSize: 11, color: context.txtMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '📅 $dateStr',
                          style: TextStyle(fontSize: 11, color: context.txtSecondary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 18),
                        tooltip: 'Remove Assignment',
                        onPressed: () => _handleRemoveAssignment(id),
                      ),
                      if (isNotified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Notified', style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/biometric_profile_model.dart';
import '../../models/face_attendance_record_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/face_attendance_log_service.dart';
import '../../services/face_recognition_service.dart';

class AdminFaceAttendanceScreen extends ConsumerStatefulWidget {
  const AdminFaceAttendanceScreen({super.key});

  @override
  ConsumerState<AdminFaceAttendanceScreen> createState() =>
      _AdminFaceAttendanceScreenState();
}

class _AdminFaceAttendanceScreenState
    extends ConsumerState<AdminFaceAttendanceScreen> {
  final FaceAttendanceLogService _logService = FaceAttendanceLogService();
  final FaceRecognitionService _faceService = FaceRecognitionService();
  final TextEditingController _searchController = TextEditingController();

  List<FaceAttendanceRecord> _allLogs = [];
  List<FaceAttendanceRecord> _filteredLogs = [];
  List<FaceBiometricProfile> _registeredProfiles = [];
  Map<String, String?> _registeredPhotos = {};

  bool _isLoading = true;
  String _selectedDateFilter = 'all'; // 'all', 'today', 'yesterday', 'custom'
  DateTime? _customSelectedDate;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final logs = await _logService.getFaceAttendanceLogs();
      final profiles = await _faceService.getAllEnrolledProfiles();

      final Map<String, String?> regPhotos = {};
      for (final p in profiles) {
        try {
          final photo = await _logService.getRegisteredFaceImage(p.userId);
          regPhotos[p.userId] = photo;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _allLogs = logs;
          _registeredProfiles = profiles;
          _registeredPhotos = regPhotos;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    if (!mounted) return;
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();

    List<FaceAttendanceRecord> list = List.from(_allLogs);

    if (_selectedDateFilter == 'today') {
      list = list.where((r) {
        return r.timestamp.year == now.year &&
            r.timestamp.month == now.month &&
            r.timestamp.day == now.day;
      }).toList();
    } else if (_selectedDateFilter == 'yesterday') {
      final yesterday = now.subtract(const Duration(days: 1));
      list = list.where((r) {
        return r.timestamp.year == yesterday.year &&
            r.timestamp.month == yesterday.month &&
            r.timestamp.day == yesterday.day;
      }).toList();
    } else if (_selectedDateFilter == 'custom' && _customSelectedDate != null) {
      list = list.where((r) {
        return r.timestamp.year == _customSelectedDate!.year &&
            r.timestamp.month == _customSelectedDate!.month &&
            r.timestamp.day == _customSelectedDate!.day;
      }).toList();
    }

    if (query.isNotEmpty) {
      list = list.where((r) {
        final name = r.userName.toLowerCase();
        final email = r.email.toLowerCase();
        final id = r.userId.toLowerCase();
        final notes = (r.notes ?? '').toLowerCase();
        return name.contains(query) ||
            email.contains(query) ||
            id.contains(query) ||
            notes.contains(query);
      }).toList();
    }

    setState(() {
      _filteredLogs = list;
    });
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _customSelectedDate ?? now,
      firstDate: DateTime(2023),
      lastDate: now,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6366F1),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1B4B),
              onSurface: Colors.white,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customSelectedDate = picked;
        _selectedDateFilter = 'custom';
      });
      _applyFilters();
    }
  }

  int get _todayScanCount {
    final now = DateTime.now();
    return _allLogs.where((r) {
      return r.timestamp.year == now.year &&
          r.timestamp.month == now.month &&
          r.timestamp.day == now.day;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;

    final bool isUserAdmin = auth.isAdmin ||
        (auth.role?.toLowerCase() == 'admin') ||
        (auth.user?['role']?.toString().toLowerCase() == 'admin');

    if (!isUserAdmin) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              size: 20,
            ),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text('Access Restricted'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_person_rounded,
                    size: 52,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Admin Access Required',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Face Lock attendance records and photos are strictly reserved for Administrators.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              size: 20,
            ),
            onPressed: () => Navigator.maybePop(context),
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.face_retouching_natural_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Face Attendance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Live Biometric Photo Logs',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF38BDF8),
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, color: Color(0xFF38BDF8), size: 22),
              tooltip: 'Refresh',
              onPressed: _isLoading ? null : _loadData,
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'clear_logs') {
                  _confirmClearLogs();
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'clear_logs',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_rounded,
                          color: Colors.redAccent, size: 18),
                      SizedBox(width: 10),
                      Text('Clear Scan History',
                          style:
                              TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: TabBar(
                indicatorColor: const Color(0xFF06B6D4),
                indicatorWeight: 3,
                labelColor: const Color(0xFF06B6D4),
                unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt_rounded, size: 16),
                        const SizedBox(width: 6),
                        const Text('Face Scans'),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF06B6D4).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_allLogs.length}',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.badge_rounded, size: 16),
                        const SizedBox(width: 6),
                        const Text('Registered Faces'),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF6366F1).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_registeredProfiles.length}',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildFaceScansTab(isDark),
            _buildRegisteredFacesTab(isDark),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: Face Scans ---
  Widget _buildFaceScansTab(bool isDark) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF06B6D4),
      child: Column(
        children: [
          _buildStatsHeader(isDark),
          _buildFilterBar(isDark),
          Expanded(
            child: _filteredLogs.isEmpty
                ? _buildEmptyState(
                    isDark,
                    title: 'No Face Lock Scans Found',
                    subtitle: _selectedDateFilter != 'all'
                        ? 'No face attendance recorded for the selected date.'
                        : 'When employees mark attendance with Face Lock, their live face photos will appear here.',
                    icon: Icons.face_retouching_off_rounded,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _filteredLogs.length,
                    itemBuilder: (ctx, index) {
                      final record = _filteredLogs[index];
                      return _buildFaceRecordCard(record, isDark, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- Stats Header ---
  Widget _buildStatsHeader(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131C2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMiniStat(
              icon: Icons.camera_front_rounded,
              color: const Color(0xFF06B6D4),
              label: 'Total Scans',
              value: '${_allLogs.length}',
            ),
          ),
          Container(
              width: 1,
              height: 36,
              color: isDark ? Colors.white12 : Colors.black12),
          Expanded(
            child: _buildMiniStat(
              icon: Icons.today_rounded,
              color: const Color(0xFF10B981),
              label: "Today's Scans",
              value: '$_todayScanCount',
            ),
          ),
          Container(
              width: 1,
              height: 36,
              color: isDark ? Colors.white12 : Colors.black12),
          Expanded(
            child: _buildMiniStat(
              icon: Icons.verified_user_rounded,
              color: const Color(0xFF6366F1),
              label: 'Enrolled Staff',
              value: '${_registeredProfiles.length}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  // --- Search & Filter Bar ---
  Widget _buildFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Search by employee name, ID or email...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 12,
                ),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: Color(0xFF06B6D4)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Scans', 'all', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Today', 'today', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Yesterday', 'yesterday', isDark),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _pickCustomDate,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedDateFilter == 'custom'
                          ? const Color(0xFF06B6D4)
                          : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedDateFilter == 'custom'
                            ? const Color(0xFF06B6D4)
                            : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFCBD5E1)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 13,
                          color: _selectedDateFilter == 'custom'
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _customSelectedDate != null &&
                                  _selectedDateFilter == 'custom'
                              ? DateFormat('dd MMM')
                                  .format(_customSelectedDate!)
                              : 'Select Date',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _selectedDateFilter == 'custom'
                                ? Colors.white
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _selectedDateFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDateFilter = value;
          if (value != 'custom') _customSelectedDate = null;
        });
        _applyFilters();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF06B6D4)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF06B6D4)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  // --- Face Record Card ---
  Widget _buildFaceRecordCard(
      FaceAttendanceRecord record, bool isDark, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131C2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showFaceInspectionDialog(record),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF10B981),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.25),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _buildFaceImageWidget(
                            record.faceImageBase64, record.userName),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
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
                              record.userName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF10B981), size: 10),
                                const SizedBox(width: 3),
                                Text(
                                  record.status.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (record.email.isNotEmpty)
                        Text(
                          record.email,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 12, color: Color(0xFF06B6D4)),
                          const SizedBox(width: 4),
                          Text(
                            record.formattedDateTime,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF334155),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF06B6D4)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.fingerprint_rounded,
                                    size: 11, color: Color(0xFF06B6D4)),
                                const SizedBox(width: 3),
                                Text(
                                  record.similarityPercent,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF06B6D4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (record.latitude != null &&
                          record.longitude != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 11, color: Colors.orangeAccent),
                            const SizedBox(width: 3),
                            Text(
                              'GPS: ${record.latitude!.toStringAsFixed(4)}, ${record.longitude!.toStringAsFixed(4)}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- TAB 2: Registered Faces ---
  Widget _buildRegisteredFacesTab(bool isDark) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6366F1)),
      );
    }

    if (_registeredProfiles.isEmpty) {
      return _buildEmptyState(
        isDark,
        title: 'No Registered Faces',
        subtitle: 'No employees have enrolled their biometric face lock yet.',
        icon: Icons.no_accounts_rounded,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _registeredProfiles.length,
      itemBuilder: (ctx, index) {
        final profile = _registeredProfiles[index];
        final photoBase64 = _registeredPhotos[profile.userId];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131C2E) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF6366F1),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: _buildFaceImageWidget(photoBase64, profile.userName),
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
                              profile.userName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ENROLLED',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${profile.userId} • Role: ${profile.role.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enrolled: ${DateFormat('dd MMM yyyy, hh:mm a').format(profile.enrolledAt)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static bool _isValidImageBytes(List<int> bytes) {
    if (bytes.length < 4) return false;
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true; // JPEG
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true; // PNG
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true; // GIF
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return true; // WEBP
    }
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) return true; // BMP
    return false;
  }

  // --- Face Image Decoder Widget ---
  Widget _buildFaceImageWidget(String? base64Str, String name) {
    if (base64Str != null && base64Str.isNotEmpty) {
      final clean = base64Str.trim();
      if (clean.startsWith('http://') || clean.startsWith('https://')) {
        return CachedNetworkImage(
          imageUrl: clean,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => _buildFallbackAvatar(name),
        );
      }
      try {
        String base64Clean = clean;
        if (base64Clean.contains(',')) {
          base64Clean = base64Clean.split(',').last;
        }
        base64Clean = base64Clean.replaceAll(RegExp(r'\s+'), '');
        while (base64Clean.length % 4 != 0) {
          base64Clean += '=';
        }
        final bytes = base64Decode(base64Clean);
        if (bytes.isNotEmpty && _isValidImageBytes(bytes)) {
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            cacheWidth: 200,
            cacheHeight: 200,
            errorBuilder: (context, error, stackTrace) =>
                _buildFallbackAvatar(name),
          );
        }
      } catch (_) {}
    }
    return _buildFallbackAvatar(name);
  }

  Widget _buildFallbackAvatar(String name) {
    final initials = name.trim().isNotEmpty
        ? name
            .trim()
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'EM';

    return Container(
      color: const Color(0xFF1E1B4B),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // --- Inspection Dialog ---
  void _showFaceInspectionDialog(FaceAttendanceRecord record) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF0F172A),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.4)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.face_retouching_natural_rounded,
                              color: Color(0xFF06B6D4), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Face Verification Log',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF10B981),
                        width: 3.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _buildFaceImageWidget(
                          record.faceImageBase64, record.userName),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt_rounded,
                            color: Color(0xFF10B981), size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Live Attendance Camera Capture',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    record.userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.email.isNotEmpty
                        ? record.email
                        : 'ID: ${record.userId}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        _buildInspectionRow('Scan Timestamp',
                            record.formattedDateTime, Icons.access_time_rounded),
                        const Divider(color: Colors.white10, height: 16),
                        _buildInspectionRow(
                            'Biometric Confidence',
                            record.similarityPercent,
                            Icons.fingerprint_rounded,
                            valueColor: const Color(0xFF10B981)),
                        const Divider(color: Colors.white10, height: 16),
                        _buildInspectionRow(
                            'Verification Status',
                            'Verified & Recorded ✓',
                            Icons.verified_user_rounded,
                            valueColor: const Color(0xFF38BDF8)),
                        if (record.latitude != null &&
                            record.longitude != null) ...[
                          const Divider(color: Colors.white10, height: 16),
                          _buildInspectionRow(
                              'GPS Location',
                              '${record.latitude!.toStringAsFixed(4)}, ${record.longitude!.toStringAsFixed(4)}',
                              Icons.location_on_rounded,
                              valueColor: Colors.orangeAccent),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Close Preview',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInspectionRow(String label, String value, IconData icon,
      {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.white54),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // --- Confirm Clear Logs ---
  void _confirmClearLogs() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Scan History?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to clear all stored face attendance scan logs? This action cannot be undone.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _logService.clearAllFaceLogs();
              _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Face scan history cleared.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child:
                const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- Empty State ---
  Widget _buildEmptyState(
    bool isDark, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: const Color(0xFF06B6D4)),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

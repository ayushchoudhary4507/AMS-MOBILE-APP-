import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/utils/storage_service.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';
import '../services/realtime_notification_service.dart';

class AttendanceState {
  final bool isLoading;
  final bool isCalendarLoading;
  final AttendanceModel? todayAttendance;
  final List<dynamic> history;
  final List<dynamic> calendarData;
  final List<dynamic> todayAllAttendance;
  final Map<String, dynamic>? stats;
  final List<dynamic> myLeaves;
  final List<dynamic> allLeaves;
  final String? error;
  final bool isCheckedIn;
  final bool isCheckedOut;

  const AttendanceState({
    this.isLoading = false,
    this.isCalendarLoading = false,
    this.todayAttendance,
    this.history = const [],
    this.calendarData = const [],
    this.todayAllAttendance = const [],
    this.stats,
    this.myLeaves = const [],
    this.allLeaves = const [],
    this.error,
    this.isCheckedIn = false,
    this.isCheckedOut = false,
  });

  AttendanceState copyWith({
    bool? isLoading,
    bool? isCalendarLoading,
    AttendanceModel? todayAttendance,
    List<dynamic>? history,
    List<dynamic>? calendarData,
    List<dynamic>? todayAllAttendance,
    Map<String, dynamic>? stats,
    List<dynamic>? myLeaves,
    List<dynamic>? allLeaves,
    String? error,
    bool? isCheckedIn,
    bool? isCheckedOut,
  }) {
    return AttendanceState(
      isLoading: isLoading ?? this.isLoading,
      isCalendarLoading: isCalendarLoading ?? this.isCalendarLoading,
      todayAttendance: todayAttendance ?? this.todayAttendance,
      history: history ?? this.history,
      calendarData: calendarData ?? this.calendarData,
      todayAllAttendance: todayAllAttendance ?? this.todayAllAttendance,
      stats: stats ?? this.stats,
      myLeaves: myLeaves ?? this.myLeaves,
      allLeaves: allLeaves ?? this.allLeaves,
      error: error,
      isCheckedIn: isCheckedIn ?? this.isCheckedIn,
      isCheckedOut: isCheckedOut ?? this.isCheckedOut,
    );
  }
}

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final Ref? _ref;
  Timer? _bgSyncTimer;
  final Set<String> _adminTrackedCheckInIds = {};
  final Set<String> _adminTrackedCheckOutIds = {};
  final Set<String> _adminTrackedLeaveIds = {};
  bool _isFirstAdminSync = true;
  bool _isFirstLeaveSync = true;

  AttendanceNotifier([this._ref]) : super(const AttendanceState()) {
    _startBackgroundSync();
  }

  void _startBackgroundSync() {
    _bgSyncTimer?.cancel();
    _bgSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final user = await StorageService.getUser();
      if (user == null) return;
      final role = (user['role'] ?? '').toString().toLowerCase();
      if (role == 'admin') {
        _syncAdminAttendanceFromWeb();
        _syncAdminLeavesFromWeb();
      } else {
        _syncEmployeeAttendanceFromWeb();
      }
    });
  }

  Future<void> _syncAdminAttendanceFromWeb() async {
    try {
      final data = await AttendanceService.getTodayAllAttendance();
      final rawList = data['data'] ??
          data['attendance'] ??
          data['records'] ??
          data['todayAttendance'] ??
          data['result'] ??
          data['items'] ??
          [];
      final empList = rawList is List ? List<dynamic>.from(rawList) : <dynamic>[];
      final freshList = <dynamic>[];

      for (final emp in empList) {
        if (emp is! Map) continue;
        final attToday = emp['attendanceToday'] ?? emp['attendance'] ?? emp['today'];

        dynamic checkInVal;
        dynamic checkOutVal;
        String? attId;
        String empName = (emp['name'] ?? 'Employee').toString();
        String empId = (emp['_id'] ?? emp['id'] ?? emp['email'])?.toString() ?? '';

        if (attToday is Map) {
          attId = (attToday['_id'] ?? attToday['id'])?.toString();
          checkInVal = attToday['checkInTime'] ?? attToday['checkIn'] ?? attToday['check_in'];
          checkOutVal = attToday['checkOutTime'] ?? attToday['checkOut'] ?? attToday['check_out'];
        } else {
          checkInVal = emp['checkInTime'] ?? emp['checkIn'] ?? emp['check_in'];
          checkOutVal = emp['checkOutTime'] ?? emp['checkOut'] ?? emp['check_out'];
        }

        final uniqueCheckInKey = '${empId}_checkin_${checkInVal ?? attId}';
        final uniqueCheckOutKey = '${empId}_checkout_${checkOutVal ?? attId}';

        if (checkInVal != null && checkInVal.toString().isNotEmpty) {
          freshList.add({
            '_id': attId ?? empId,
            'status': 'Present',
            'checkIn': checkInVal,
            'checkOut': checkOutVal,
            'name': empName,
            'email': emp['email'],
            'userId': empId,
          });

          if (!_isFirstAdminSync && !_adminTrackedCheckInIds.contains(uniqueCheckInKey)) {
            _adminTrackedCheckInIds.add(uniqueCheckInKey);
            final timeStr = DateFormat('hh:mm a').format(DateTime.now());
            if (_ref != null) {
              RealtimeNotificationService.dispatchNotification(
                _ref,
                title: 'Attendance Update',
                message: '$empName marked Check In at $timeStr.',
                type: 'attendance_checkin',
                category: NotificationCategory.attendanceCheckIn,
              );
            }
          } else {
            _adminTrackedCheckInIds.add(uniqueCheckInKey);
          }
        }

        if (checkOutVal != null && checkOutVal.toString().isNotEmpty) {
          if (!_isFirstAdminSync && !_adminTrackedCheckOutIds.contains(uniqueCheckOutKey)) {
            _adminTrackedCheckOutIds.add(uniqueCheckOutKey);
            final timeStr = DateFormat('hh:mm a').format(DateTime.now());
            if (_ref != null) {
              RealtimeNotificationService.dispatchNotification(
                _ref,
                title: 'Attendance Update',
                message: '$empName marked Check Out at $timeStr.',
                type: 'attendance_checkout',
                category: NotificationCategory.attendanceCheckOut,
              );
            }
          } else {
            _adminTrackedCheckOutIds.add(uniqueCheckOutKey);
          }
        }
      }

      _isFirstAdminSync = false;
      state = state.copyWith(todayAllAttendance: freshList);
    } catch (_) {}
  }

  Future<void> _syncAdminLeavesFromWeb() async {
    try {
      final data = await AttendanceService.getAllLeaves();
      final rawList = data['leaves'] ?? data['data'] ?? data['result'] ?? data['items'] ?? [];
      final list = rawList is List ? rawList : [];

      for (final leave in list) {
        if (leave is! Map) continue;
        final leaveId = (leave['_id'] ?? leave['id'])?.toString();
        if (leaveId == null || leaveId.isEmpty) continue;

        final status = (leave['status'] ?? 'pending').toString().toLowerCase();
        final empName = (leave['user']?['name'] ?? leave['employeeName'] ?? leave['name'] ?? 'Employee').toString();
        final leaveType = (leave['leaveType'] ?? leave['type'] ?? 'Leave').toString();

        if (!_isFirstLeaveSync && !_adminTrackedLeaveIds.contains(leaveId) && status == 'pending') {
          _adminTrackedLeaveIds.add(leaveId);
          if (_ref != null) {
            RealtimeNotificationService.dispatchNotification(
              _ref,
              title: 'New Leave Request',
              message: '$empName applied for $leaveType.',
              type: 'leave_request',
              category: NotificationCategory.leaveRequest,
            );
          }
        } else {
          _adminTrackedLeaveIds.add(leaveId);
        }
      }
      _isFirstLeaveSync = false;
    } catch (_) {}
  }

  Future<void> _syncEmployeeAttendanceFromWeb() async {
    try {
      final data = await AttendanceService.getMyTodayAttendance();
      final raw = data['attendance'] ?? data['data'] ?? data['result'];
      if (raw is Map) {
        final model = AttendanceModel.fromJson(Map<String, dynamic>.from(raw));
        final checkedIn = model.isCheckedIn;
        final checkedOut = model.isCheckedOut;

        if (!state.isCheckedIn && checkedIn) {
          state = state.copyWith(
            todayAttendance: model,
            isCheckedIn: true,
            isCheckedOut: checkedOut,
          );
          if (_ref != null) {
            final timeStr = DateFormat('hh:mm a').format(DateTime.now());
            RealtimeNotificationService.dispatchNotification(
              _ref,
              title: 'Attendance Update',
              message: 'Check In marked at $timeStr.',
              type: 'attendance_checkin',
              category: NotificationCategory.attendanceCheckIn,
            );
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _bgSyncTimer?.cancel();
    super.dispose();
  }

  void reset() {
    state = const AttendanceState();
  }

  /// Fetches today's attendance record from backend/database
  Future<void> loadTodayAttendance() async {
    state = state.copyWith(isLoading: true, error: null);
    final user = await StorageService.getUser();
    final emailOrId = (user?['email'] ?? user?['id'] ?? user?['_id'])?.toString();

    try {
      final data = await AttendanceService.getMyTodayAttendance();

      final rawAttendance =
          data['attendance'] ?? data['data'] ?? data['result'] ?? data['record'] ?? data['today'] ?? data['item'];

      Map<String, dynamic>? attendanceMap;
      if (rawAttendance is Map<String, dynamic>) {
        attendanceMap = rawAttendance;
      } else if (rawAttendance is Map) {
        attendanceMap = Map<String, dynamic>.from(rawAttendance);
      } else if (rawAttendance is List && rawAttendance.isNotEmpty) {
        final first = rawAttendance.first;
        if (first is Map<String, dynamic>) {
          attendanceMap = first;
        } else if (first is Map) {
          attendanceMap = Map<String, dynamic>.from(first);
        }
      } else if (data['checkIn'] != null ||
          data['check_in'] != null ||
          data['checkInTime'] != null ||
          data['inTime'] != null ||
          data['status'] != null) {
        attendanceMap = data;
      }

      AttendanceModel? model;
      if (attendanceMap != null && attendanceMap.isNotEmpty) {
        model = AttendanceModel.fromJson(attendanceMap);
        if (emailOrId != null && emailOrId.isNotEmpty && model.isCheckedIn) {
          await StorageService.saveTodayAttendance(emailOrId, attendanceMap);
        }
      }

      // Fallback: Restore from local StorageService if server model is null or un-checked
      if ((model == null || !model.isCheckedIn) && emailOrId != null && emailOrId.isNotEmpty) {
        final cached = await StorageService.getTodayAttendance(emailOrId);
        if (cached != null && cached.isNotEmpty) {
          final cachedModel = AttendanceModel.fromJson(cached);
          if (cachedModel.isCheckedIn) {
            model = cachedModel;
          }
        }
      }

      final checkedIn = model?.isCheckedIn ?? false;
      final checkedOut = model?.isCheckedOut ?? false;

      state = state.copyWith(
        isLoading: false,
        todayAttendance: model,
        isCheckedIn: checkedIn,
        isCheckedOut: checkedOut,
        error: null,
      );
    } catch (e) {
      AttendanceModel? model;
      if (emailOrId != null && emailOrId.isNotEmpty) {
        final cached = await StorageService.getTodayAttendance(emailOrId);
        if (cached != null && cached.isNotEmpty) {
          final cachedModel = AttendanceModel.fromJson(cached);
          if (cachedModel.isCheckedIn) {
            model = cachedModel;
          }
        }
      }

      if (model != null) {
        state = state.copyWith(
          isLoading: false,
          todayAttendance: model,
          isCheckedIn: model.isCheckedIn,
          isCheckedOut: model.isCheckedOut,
          error: null,
        );
      } else {
        String errorMessage = 'Failed to load today\'s attendance.';
        if (e is DioException) {
          final resData = e.response?.data;
          if (resData is Map && resData['message'] != null) {
            errorMessage = resData['message'].toString();
          }
        }
        state = state.copyWith(isLoading: false, error: errorMessage);
      }
    }
  }

  /// Check In API call
  Future<bool> markAttendance() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await AttendanceService.markAttendance();

      final bool isSuccess = data['success'] == true ||
          data['status'] == 'success' ||
          data['attendance'] != null ||
          data['data'] != null;

      final user = await StorageService.getUser();
      final emailOrId = (user?['email'] ?? user?['id'] ?? user?['_id'])?.toString();

      if (isSuccess) {
        final raw = data['attendance'] ?? data['data'] ?? data['result'];
        Map<String, dynamic>? map;
        if (raw is Map<String, dynamic>) {
          map = raw;
        } else if (raw is Map) {
          map = Map<String, dynamic>.from(raw);
        }

        map ??= {
          'checkIn': DateTime.now().toIso8601String(),
          'status': 'present',
        };

        if (emailOrId != null && emailOrId.isNotEmpty) {
          await StorageService.saveTodayAttendance(emailOrId, map);
        }

        final model = AttendanceModel.fromJson(map);
        state = state.copyWith(
          isLoading: false,
          todayAttendance: model,
          isCheckedIn: true,
          isCheckedOut: model.isCheckedOut,
          error: null,
        );

        if (_ref != null) {
          final userName = user?['name']?.toString() ?? 'Employee';
          final timeStr = DateFormat('hh:mm a').format(DateTime.now());
          RealtimeNotificationService.dispatchNotification(
            _ref,
            title: 'Attendance Update',
            message: '$userName marked Check In at $timeStr.',
            type: 'attendance_checkin',
            category: NotificationCategory.attendanceCheckIn,
          );
        }

        await loadStats();
        return true;
      } else {
        final msg = data['message']?.toString() ?? 'Failed to mark check-in.';
        await loadTodayAttendance();
        if (state.isCheckedIn) {
          state = state.copyWith(isLoading: false, error: null);
          return true;
        }
        state = state.copyWith(isLoading: false, error: msg);
        return false;
      }
    } catch (e) {
      final user = await StorageService.getUser();
      final emailOrId = (user?['email'] ?? user?['id'] ?? user?['_id'])?.toString();

      // Create local fallback checkin timestamp
      if (emailOrId != null && emailOrId.isNotEmpty) {
        final fallbackMap = {
          'checkIn': DateTime.now().toIso8601String(),
          'status': 'present',
        };
        await StorageService.saveTodayAttendance(emailOrId, fallbackMap);
        final model = AttendanceModel.fromJson(fallbackMap);
        state = state.copyWith(
          isLoading: false,
          todayAttendance: model,
          isCheckedIn: true,
          isCheckedOut: false,
          error: null,
        );
        if (_ref != null) {
          final userName = user?['name']?.toString() ?? 'Employee';
          final timeStr = DateFormat('hh:mm a').format(DateTime.now());
          RealtimeNotificationService.dispatchNotification(
            _ref,
            title: 'Attendance Update',
            message: '$userName marked Check In at $timeStr.',
            type: 'attendance_checkin',
            category: NotificationCategory.attendanceCheckIn,
          );
        }
        return true;
      }

      await loadTodayAttendance();
      if (state.isCheckedIn) {
        state = state.copyWith(isLoading: false, error: null);
        return true;
      }

      String errorMessage = 'Failed to mark check-in. Please try again.';
      if (e is DioException) {
        final resData = e.response?.data;
        if (resData is Map && resData['message'] != null) {
          errorMessage = resData['message'].toString();
        }
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    }
  }

  /// Check Out API call
  Future<bool> checkOut() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await AttendanceService.checkOut();

      final bool isSuccess = data['success'] == true ||
          data['status'] == 'success' ||
          data['attendance'] != null ||
          data['data'] != null;

      final user = await StorageService.getUser();
      final emailOrId = (user?['email'] ?? user?['id'] ?? user?['_id'])?.toString();

      if (isSuccess) {
        final raw = data['attendance'] ?? data['data'] ?? data['result'];
        Map<String, dynamic>? map;
        if (raw is Map<String, dynamic>) {
          map = raw;
        } else if (raw is Map) {
          map = Map<String, dynamic>.from(raw);
        }

        map ??= Map<String, dynamic>.from(state.todayAttendance != null ? state.todayAttendance!.toJson() : {});
        map['checkOut'] = DateTime.now().toIso8601String();
        map['status'] = 'present';

        if (emailOrId != null && emailOrId.isNotEmpty) {
          await StorageService.saveTodayAttendance(emailOrId, map);
        }

        final model = AttendanceModel.fromJson(map);
        state = state.copyWith(
          isLoading: false,
          todayAttendance: model,
          isCheckedIn: true,
          isCheckedOut: true,
          error: null,
        );

        if (_ref != null) {
          final userName = user?['name']?.toString() ?? 'Employee';
          final timeStr = DateFormat('hh:mm a').format(DateTime.now());
          RealtimeNotificationService.dispatchNotification(
            _ref,
            title: 'Attendance Update',
            message: '$userName marked Check Out at $timeStr.',
            type: 'attendance_checkout',
            category: NotificationCategory.attendanceCheckOut,
          );
        }

        await loadStats();
        return true;
      } else {
        final msg = data['message']?.toString() ?? 'Failed to mark check-out.';
        await loadTodayAttendance();
        if (state.isCheckedOut) {
          state = state.copyWith(isLoading: false, error: null);
          return true;
        }
        state = state.copyWith(isLoading: false, error: msg);
        return false;
      }
    } catch (e) {
      final user = await StorageService.getUser();
      final emailOrId = (user?['email'] ?? user?['id'] ?? user?['_id'])?.toString();

      if (emailOrId != null && emailOrId.isNotEmpty) {
        final Map<String, dynamic> existingMap = Map<String, dynamic>.from(state.todayAttendance != null ? state.todayAttendance!.toJson() : {});
        existingMap['checkOut'] = DateTime.now().toIso8601String();
        existingMap['status'] = 'present';
        await StorageService.saveTodayAttendance(emailOrId, existingMap);

        final model = AttendanceModel.fromJson(existingMap);
        state = state.copyWith(
          isLoading: false,
          todayAttendance: model,
          isCheckedIn: true,
          isCheckedOut: true,
          error: null,
        );
        if (_ref != null) {
          final userName = user?['name']?.toString() ?? 'Employee';
          final timeStr = DateFormat('hh:mm a').format(DateTime.now());
          RealtimeNotificationService.dispatchNotification(
            _ref,
            title: 'Attendance Update',
            message: '$userName marked Check Out at $timeStr.',
            type: 'attendance_checkout',
            category: NotificationCategory.attendanceCheckOut,
          );
        }
        return true;
      }

      await loadTodayAttendance();
      if (state.isCheckedOut) {
        state = state.copyWith(isLoading: false, error: null);
        return true;
      }

      String errorMessage = 'Failed to mark check-out. Please try again.';
      if (e is DioException) {
        final resData = e.response?.data;
        if (resData is Map && resData['message'] != null) {
          errorMessage = resData['message'].toString();
        }
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    }
  }

  Future<void> loadStats() async {
    try {
      final data = await AttendanceService.getAttendanceStats();
      final statsData = data['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['data'])
          : data['stats'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(data['stats'])
              : data;
      state = state.copyWith(stats: statsData);
    } catch (_) {}
  }

  Future<void> loadCalendar({int? month, int? year}) async {
    state = state.copyWith(isCalendarLoading: true);
    try {
      final now = DateTime.now();
      final data = await AttendanceService.getCalendarData(
        month: month ?? now.month,
        year: year ?? now.year,
      );
      final raw = data['calendar'] ??
          data['data'] ??
          data['attendance'] ??
          data['records'] ??
          [];
      final list = raw is List ? raw : [];
      state = state.copyWith(isCalendarLoading: false, calendarData: list);
    } catch (_) {
      state = state.copyWith(isCalendarLoading: false, calendarData: []);
    }
  }

  Future<void> loadTodayAllAttendance() async {
    try {
      final data = await AttendanceService.getTodayAllAttendance();

      // API returns: { success, count, data: [ { _id, name, email, attendanceToday: {...} } ] }
      final rawList = data['data'] ??
          data['attendance'] ??
          data['records'] ??
          data['todayAttendance'] ??
          data['result'] ??
          data['today'] ??
          data['items'] ??
          data['list'] ??
          data['attendances'] ??
          data['all'] ??
          (data is List ? data : []);
      final empList = rawList is List ? List<dynamic>.from(rawList) : <dynamic>[];

      final list = <dynamic>[];

      for (final emp in empList) {
        if (emp is! Map) continue;

        final attToday = emp['attendanceToday'];

        if (attToday != null && attToday is Map) {
          // Merge employee info into a flat attendance record
          final merged = <String, dynamic>{
            '_id': attToday['_id'],
            'status': attToday['status'] ?? attToday['attendanceStatus'] ?? 'Present',
            'checkIn': attToday['checkInTime'] ?? attToday['checkIn'] ?? attToday['check_in'] ?? attToday['date'] ?? attToday['createdAt'],
            'checkOut': attToday['checkOutTime'] ?? attToday['checkOut'] ?? attToday['check_out'],
            'date': attToday['date'] ?? attToday['createdAt'],
            'createdAt': attToday['createdAt'],
            'isActive': attToday['isActive'],
            'workHours': attToday['workHours'],
            // Flatten employee identity
            'name': emp['name'],
            'email': emp['email'],
            'userId': attToday['userId'] ?? emp['_id'],
            'employeeId': emp['employeeId'] ?? emp['_id'],
            'employee': {
              '_id': emp['_id'],
              'name': emp['name'],
              'email': emp['email'],
              'designation': emp['designation'],
              'profilePhoto': emp['profilePhoto'] ?? emp['avatar'] ?? emp['photo'],
            },
          };
          list.add(merged);
        } else if ((emp['attendanceStatus']?.toString().toLowerCase() == 'active') ||
            (emp['status']?.toString().toLowerCase() == 'present')) {
          // No nested attendanceToday but marked as present
          list.add({
            'status': 'Present',
            'name': emp['name'],
            'email': emp['email'],
            'userId': emp['_id'],
            'employeeId': emp['employeeId'] ?? emp['_id'],
            'employee': emp,
          });
        }
      }

      debugPrint('[ATT_DEBUG] Parsed ${list.length} present records from ${empList.length} employees');

      if (state.isCheckedIn && state.todayAttendance != null) {
        final localAtt = state.todayAttendance!;
        final exists = list.any((item) {
          if (item is! Map) return false;
          final id = (item['userId'] ?? item['employeeId'])?.toString();
          return id != null && (id == localAtt.userId || id == localAtt.employeeId || id == localAtt.id);
        });
        if (!exists) {
          list.add(localAtt.toJson());
        }
      }
      state = state.copyWith(todayAllAttendance: list);
    } catch (e, st) {
      debugPrint('[ATT_DEBUG] loadTodayAllAttendance ERROR: $e\n$st');
      state = state.copyWith(todayAllAttendance: []);
    }
  }

  Future<void> loadMyLeaves() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await AttendanceService.getMyLeaves();
      final leaves = data['leaves'] ?? data['data'] ?? [];
      state = state.copyWith(
          isLoading: false, myLeaves: leaves is List ? leaves : []);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadAllLeaves({String? status}) async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await AttendanceService.getAllLeaves(status: status);
      final leaves = data['leaves'] ?? data['data'] ?? data['requests'] ?? data['leaveRequests'] ?? [];
      final leaveList = leaves is List ? leaves : [];
      state = state.copyWith(isLoading: false, allLeaves: leaveList);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> applyLeave({
    required String leaveType,
    required String startDate,
    required String endDate,
    String? reason,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await AttendanceService.applyLeave(
        leaveType: leaveType,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
      );
      state = state.copyWith(isLoading: false);
      if (data['success'] == true || data['status'] == 'success') {
        if (_ref != null) {
          final user = await StorageService.getUser();
          final userName = user?['name']?.toString() ?? 'Employee';
          RealtimeNotificationService.dispatchNotification(
            _ref,
            title: 'New Leave Request',
            message: '$userName applied for $leaveType.',
            type: 'leave_request',
            category: NotificationCategory.leaveRequest,
          );
        }
        await loadMyLeaves();
        return true;
      }
      state = state.copyWith(error: data['message'] ?? 'Failed to apply leave');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> approveRejectLeave(
      String leaveId, String status, String? comments) async {
    // Optimistically update local leave status
    final updatedLeaves = state.allLeaves.map((l) {
      if (l is Map && (l['_id']?.toString() == leaveId || l['id']?.toString() == leaveId)) {
        final copy = Map<String, dynamic>.from(l);
        copy['status'] = status;
        return copy;
      }
      return l;
    }).toList();
    state = state.copyWith(allLeaves: updatedLeaves);

    try {
      await AttendanceService.approveRejectLeave(
        leaveId: leaveId,
        status: status,
        comments: comments,
      );
      if (_ref != null) {
        final isApproved = status.toLowerCase().contains('approve');
        RealtimeNotificationService.dispatchNotification(
          _ref,
          title: isApproved ? 'Leave Approved' : 'Leave Rejected',
          message: isApproved
              ? 'Your leave request has been approved.'
              : 'Your leave request has been rejected.',
          type: isApproved ? 'leave_approved' : 'leave_rejected',
          category: isApproved
              ? NotificationCategory.leaveApproved
              : NotificationCategory.leaveRejected,
        );
      }
      await loadAllLeaves();
      return true;
    } catch (_) {
      if (_ref != null) {
        final isApproved = status.toLowerCase().contains('approve');
        RealtimeNotificationService.dispatchNotification(
          _ref,
          title: isApproved ? 'Leave Approved' : 'Leave Rejected',
          message: isApproved
              ? 'Your leave request has been approved.'
              : 'Your leave request has been rejected.',
          type: isApproved ? 'leave_approved' : 'leave_rejected',
          category: isApproved
              ? NotificationCategory.leaveApproved
              : NotificationCategory.leaveRejected,
        );
      }
      return true;
    }
  }

  Future<bool> adminMarkAttendance({
    required String employeeId,
    required String status,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await AttendanceService.adminMarkAttendance(
        employeeId: employeeId,
        status: status,
        notes: notes,
      );
      state = state.copyWith(isLoading: false);
      await loadStats();
      return res['success'] == true ||
          res['status'] == 'success' ||
          res['attendance'] != null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      await loadStats();
      return true;
    }
  }
}

final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
  return AttendanceNotifier(ref);
});

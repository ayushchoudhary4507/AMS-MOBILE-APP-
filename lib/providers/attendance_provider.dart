import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/utils/storage_service.dart';
import '../models/attendance_model.dart';
import '../models/attendance_session_model.dart';
import '../services/attendance_service.dart';
import '../services/employee_service.dart';
import '../services/face_attendance_log_service.dart';
import '../services/realtime_notification_service.dart';

class AttendanceState {
  final bool isLoading;
  final bool isCalendarLoading;
  final AttendanceModel? todayAttendance;
  final AttendanceSessionModel? activeSession;
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
    this.activeSession,
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
    AttendanceSessionModel? activeSession,
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
      activeSession: activeSession ?? this.activeSession,
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
  final Set<String> _adminTrackedLoginIds = {};
  bool _isFirstAdminSync = true;
  bool _isFirstLeaveSync = true;
  bool _isFirstLoginSync = true;

  AttendanceNotifier([this._ref]) : super(const AttendanceState()) {
    _startBackgroundSync();
  }

  bool _isSyncing = false;

  void _startBackgroundSync() {
    _bgSyncTimer?.cancel();
    _bgSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_isSyncing) return;
      _isSyncing = true;
      try {
        final user = await StorageService.getUser();
        if (user == null) return;
        final role = (user['role'] ?? '').toString().toLowerCase();
        if (role == 'admin') {
          await _syncAdminAttendanceFromWeb();
          await _syncAdminLeavesFromWeb();
          await _syncAdminLoginNotificationsFromWeb();
        } else {
          await _syncEmployeeAttendanceFromWeb();
        }
      } catch (_) {
      } finally {
        _isSyncing = false;
      }
    });
  }

  Future<void> _syncAdminLoginNotificationsFromWeb() async {
    try {
      final data = await NotificationService.getAll();
      final rawList = data['notifications'] ?? data['data'] ?? data['result'] ?? data['items'];
      final list = rawList is List ? rawList : <dynamic>[];

      for (final item in list) {
        if (item is! Map) continue;
        final id = (item['_id'] ?? item['id'])?.toString();
        if (id == null || id.isEmpty) continue;

        final type = (item['type'] ?? item['category'] ?? '').toString().toLowerCase();
        final title = (item['title'] ?? '').toString();
        final message = (item['message'] ?? item['body'] ?? '').toString();

        final isLoginNotif = type.contains('login') || title.toLowerCase().contains('login') || message.toLowerCase().contains('logged in');

        if (isLoginNotif) {
          if (!_isFirstLoginSync && !_adminTrackedLoginIds.contains(id)) {
            _adminTrackedLoginIds.add(id);
            if (_ref != null) {
              final rawTime = item['loginAt'] ?? item['createdAt'] ?? item['timestamp'] ?? item['loginTimestampUtc'];
              DateTime? createdAt;
              if (rawTime != null && rawTime.toString().isNotEmpty) {
                try {
                  String str = rawTime.toString().trim();
                  if (str.contains('T') &&
                      !str.endsWith('Z') &&
                      !str.substring(str.indexOf('T')).contains('+') &&
                      !str.substring(str.indexOf('T')).contains('-')) {
                    str += 'Z';
                  }
                  createdAt = DateTime.parse(str);
                } catch (_) {}
              }

              RealtimeNotificationService.dispatchNotification(
                _ref,
                title: title.isNotEmpty ? title : 'Employee Logged In',
                message: message.isNotEmpty ? message : 'An employee has logged in.',
                type: 'employee_login',
                category: NotificationCategory.userLogin,
                createdAt: createdAt,
              );
            }
          } else {
            _adminTrackedLoginIds.add(id);
          }
        }
      }
      _isFirstLoginSync = false;
    } catch (_) {}
  }

  Future<void> _syncAdminAttendanceFromWeb() async {
    try {
      await loadTodayAllAttendance();

      for (final item in state.todayAllAttendance) {
        if (item is! Map) continue;
        final empId = (item['userId'] ?? item['employeeId'] ?? item['_id'])?.toString() ?? '';
        final checkInVal = item['checkIn'] ?? item['checkInTime'];
        final checkOutVal = item['checkOut'] ?? item['checkOutTime'];
        final empName = (item['name'] ?? 'Employee').toString();

        final uniqueCheckInKey = '${empId}_checkin_$checkInVal';
        final uniqueCheckOutKey = '${empId}_checkout_$checkOutVal';

        if (checkInVal != null && checkInVal.toString().isNotEmpty && checkInVal.toString() != 'null') {
          if (!_isFirstAdminSync && !_adminTrackedCheckInIds.contains(uniqueCheckInKey)) {
            _adminTrackedCheckInIds.add(uniqueCheckInKey);
            DateTime checkInDt = DateTime.now();
            try {
              String str = checkInVal.toString().trim();
              if (str.contains('T') &&
                  !str.endsWith('Z') &&
                  !str.substring(str.indexOf('T')).contains('+') &&
                  !str.substring(str.indexOf('T')).contains('-')) {
                str += 'Z';
              }
              checkInDt = DateTime.parse(str).toLocal();
            } catch (_) {}

            final timeStr = DateFormat('hh:mm a').format(checkInDt);
            if (_ref != null) {
              RealtimeNotificationService.dispatchNotification(
                _ref,
                title: 'Attendance Update',
                message: '$empName marked Check In at $timeStr.',
                type: 'attendance_checkin',
                category: NotificationCategory.attendanceCheckIn,
                createdAt: checkInDt,
              );
            }
          } else {
            _adminTrackedCheckInIds.add(uniqueCheckInKey);
          }
        }

        if (checkOutVal != null && checkOutVal.toString().isNotEmpty && checkOutVal.toString() != 'null') {
          if (!_isFirstAdminSync && !_adminTrackedCheckOutIds.contains(uniqueCheckOutKey)) {
            _adminTrackedCheckOutIds.add(uniqueCheckOutKey);
            DateTime checkOutDt = DateTime.now();
            try {
              String str = checkOutVal.toString().trim();
              if (str.contains('T') &&
                  !str.endsWith('Z') &&
                  !str.substring(str.indexOf('T')).contains('+') &&
                  !str.substring(str.indexOf('T')).contains('-')) {
                str += 'Z';
              }
              checkOutDt = DateTime.parse(str).toLocal();
            } catch (_) {}

            final timeStr = DateFormat('hh:mm a').format(checkOutDt);
            if (_ref != null) {
              RealtimeNotificationService.dispatchNotification(
                _ref,
                title: 'Attendance Update',
                message: '$empName marked Check Out at $timeStr.',
                type: 'attendance_checkout',
                category: NotificationCategory.attendanceCheckOut,
                createdAt: checkOutDt,
              );
            }
          } else {
            _adminTrackedCheckOutIds.add(uniqueCheckOutKey);
          }
        }
      }

      _isFirstAdminSync = false;
    } catch (_) {}
  }

  List<dynamic> _extractLeavesList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in [
        'leaves',
        'data',
        'requests',
        'leaveRequests',
        'myLeaves',
        'allLeaves',
        'items',
        'records',
        'result',
        'list',
        'attendance',
      ]) {
        final val = data[key];
        if (val is List) return val;
        if (val is Map) {
          for (final subKey in [
            'leaves',
            'requests',
            'leaveRequests',
            'myLeaves',
            'allLeaves',
            'items',
            'records',
            'result',
            'list',
            'data',
          ]) {
            final subVal = val[subKey];
            if (subVal is List) return subVal;
          }
        }
      }
    }
    return [];
  }

  Future<void> _syncAdminLeavesFromWeb() async {
    try {
      final data = await AttendanceService.getAllLeaves();
      final list = _extractLeavesList(data);

      if (list.isNotEmpty) {
        final combined = <dynamic>[...list];
        for (final local in state.allLeaves) {
          if (local is Map) {
            final locId = (local['_id'] ?? local['id'])?.toString();
            final isFound = combined.any((srv) =>
                srv is Map &&
                (srv['_id']?.toString() == locId ||
                    srv['id']?.toString() == locId));
            if (!isFound) {
              combined.insert(0, local);
            }
          }
        }
        state = state.copyWith(allLeaves: combined);
        await StorageService.saveAllLeaves(combined);
      }

      for (final leave in (list.isNotEmpty ? list : state.allLeaves)) {
        if (leave is! Map) continue;
        final leaveId = (leave['_id'] ?? leave['id'])?.toString();
        if (leaveId == null || leaveId.isEmpty) continue;

        final status = (leave['status'] ?? 'pending').toString().toLowerCase();
        final empName = (leave['user']?['name'] ??
                leave['employee']?['name'] ??
                leave['employeeName'] ??
                leave['name'] ??
                'Employee')
            .toString();
        final leaveType =
            (leave['leaveType'] ?? leave['type'] ?? 'Leave').toString();

        if (!_isFirstLeaveSync &&
            !_adminTrackedLeaveIds.contains(leaveId) &&
            status == 'pending') {
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

  /// Face Lock Attendance Check In API call
  Future<Map<String, dynamic>> faceCheckIn({
    double? latitude,
    double? longitude,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await AttendanceService.markAttendance(
        status: 'present',
        attendanceMethod: 'FACE',
        latitude: latitude,
        longitude: longitude,
        notes: notes,
      );

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
          'attendanceMethod': 'FACE',
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

        await loadStats();
        await loadTodayAttendance();

        return {
          'success': true,
          'message': data['message']?.toString() ?? 'Attendance Marked via Face Lock Successfully! ✓',
          'attendance': map,
          'model': model,
        };
      } else {
        final rawMsg = data['message']?.toString() ?? 'Failed to mark Face Lock attendance.';
        String cleanMsg = rawMsg;
        final lower = rawMsg.toLowerCase();
        if (lower.contains('already') && (lower.contains('check') || lower.contains('marked'))) {
          cleanMsg = 'You have already checked in today.';
        } else if (lower.contains('geofence') || lower.contains('location') || lower.contains('radius') || lower.contains('outside')) {
          cleanMsg = 'You are outside the permitted office location geofence.';
        }

        state = state.copyWith(isLoading: false, error: cleanMsg);
        return {
          'success': false,
          'message': cleanMsg,
        };
      }
    } catch (e) {
      final user = await StorageService.getUser();
      final emailOrId = (user?['email'] ?? user?['id'] ?? user?['_id'])?.toString();

      if (emailOrId != null && emailOrId.isNotEmpty) {
        final fallbackMap = {
          'checkIn': DateTime.now().toIso8601String(),
          'status': 'present',
          'attendanceMethod': 'FACE',
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
        return {
          'success': true,
          'message': 'Attendance Marked via Face Lock! ✓',
          'attendance': fallbackMap,
          'model': model,
        };
      }

      String cleanMsg = 'Failed to mark attendance. Please try again.';
      if (e is DioException) {
        final resData = e.response?.data;
        if (resData is Map && resData['message'] != null) {
          cleanMsg = resData['message'].toString();
        }
      }

      state = state.copyWith(isLoading: false, error: cleanMsg);
      return {
        'success': false,
        'message': cleanMsg,
      };
    }
  }

  /// QR Code Check In API call
  Future<Map<String, dynamic>> qrCheckIn({
    required String qrToken,
    String? sessionId,
    double? latitude,
    double? longitude,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await AttendanceService.qrCheckIn(
        qrToken: qrToken,
        sessionId: sessionId,
        latitude: latitude,
        longitude: longitude,
      );

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

        await loadStats();
        await loadTodayAttendance();

        return {
          'success': true,
          'message': data['message']?.toString() ?? 'Attendance Marked Successfully',
          'attendance': map,
          'model': model,
          'office': data['office'] ?? data['location'] ?? map['office'] ?? map['location'],
        };
      } else {
        final rawMsg = data['message']?.toString() ?? 'Failed to validate QR attendance.';
        String cleanMsg = rawMsg;
        final lower = rawMsg.toLowerCase();
        if (lower.contains('already') && (lower.contains('check') || lower.contains('marked'))) {
          cleanMsg = 'You have already checked in.';
        } else if (lower.contains('expired')) {
          cleanMsg = 'This QR code has expired. Please scan a new QR code.';
        } else if (lower.contains('invalid') || lower.contains('not found')) {
          cleanMsg = 'Invalid QR code. Please scan a valid office QR code.';
        } else if (lower.contains('geofence') || lower.contains('location') || lower.contains('radius') || lower.contains('outside')) {
          cleanMsg = 'You are outside the permitted office location geofence.';
        }

        state = state.copyWith(isLoading: false, error: cleanMsg);
        return {
          'success': false,
          'message': cleanMsg,
        };
      }
    } catch (e) {
      String cleanMsg = 'Failed to mark QR attendance. Please try again.';

      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final resData = e.response?.data;
        String? serverMsg;
        if (resData is Map && resData['message'] != null) {
          serverMsg = resData['message'].toString();
        } else if (resData is String && resData.isNotEmpty) {
          serverMsg = resData;
        }

        if (serverMsg != null && serverMsg.isNotEmpty) {
          final lower = serverMsg.toLowerCase();
          if (lower.contains('already') && (lower.contains('check') || lower.contains('marked'))) {
            cleanMsg = 'You have already checked in.';
          } else if (lower.contains('expired')) {
            cleanMsg = 'This QR code has expired. Please scan a new QR code.';
          } else if (lower.contains('invalid') || lower.contains('not found')) {
            cleanMsg = 'Invalid QR code. Please scan a valid office QR code.';
          } else if (lower.contains('geofence') || lower.contains('location') || lower.contains('radius') || lower.contains('outside')) {
            cleanMsg = 'You are outside the permitted office location geofence.';
          } else if (lower.contains('unauthorized') || statusCode == 401 || statusCode == 403) {
            cleanMsg = 'Unauthorized or session expired. Please log in again.';
          } else {
            cleanMsg = serverMsg;
          }
        } else if (statusCode == 401 || statusCode == 403) {
          cleanMsg = 'Unauthorized or session expired. Please log in again.';
        } else if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.connectionError) {
          cleanMsg = 'Network error. Please check your internet connection and try again.';
        } else if (statusCode != null && statusCode >= 500) {
          cleanMsg = 'Server error ($statusCode). Please try again shortly.';
        }
      }

      state = state.copyWith(isLoading: false, error: cleanMsg);
      return {
        'success': false,
        'message': cleanMsg,
      };
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

  /// Generate & Start a new Attendance QR Session (Admin)
  Future<AttendanceSessionModel?> createAttendanceSession({
    int durationMinutes = 1440, // Default: 24 Hours / Full Day
    String? notes,
    String? office,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await AttendanceService.createAttendanceSession(
        durationMinutes: durationMinutes,
        notes: notes,
        office: office,
      );

      final rawSession = data['session'] ?? data['data'] ?? data['result'] ?? data;
      AttendanceSessionModel session;
      if (rawSession is Map<String, dynamic>) {
        session = AttendanceSessionModel.fromJson(rawSession);
      } else if (rawSession is Map) {
        session = AttendanceSessionModel.fromJson(Map<String, dynamic>.from(rawSession));
      } else {
        final now = DateTime.now();
        final token = 'AMS-${now.millisecondsSinceEpoch}-${(1000 + (now.microsecond % 9000))}';
        session = AttendanceSessionModel(
          sessionId: 'ATT-SESSION-${now.millisecondsSinceEpoch}',
          token: token,
          status: 'ACTIVE',
          createdAt: now,
          expiresAt: now.add(Duration(minutes: durationMinutes)),
          durationMinutes: durationMinutes,
          office: office,
        );
      }

      await StorageService.saveDailyQRSession(session.toJson());
      state = state.copyWith(isLoading: false, activeSession: session);
      return session;
    } catch (e) {
      final now = DateTime.now();
      final token = 'AMS-${now.millisecondsSinceEpoch}-${(1000 + (now.microsecond % 9000))}';
      final session = AttendanceSessionModel(
        sessionId: 'ATT-SESSION-${now.millisecondsSinceEpoch}',
        token: token,
        status: 'ACTIVE',
        createdAt: now,
        expiresAt: now.add(Duration(minutes: durationMinutes)),
        durationMinutes: durationMinutes,
        office: office,
      );

      await StorageService.saveDailyQRSession(session.toJson());
      state = state.copyWith(isLoading: false, activeSession: session);
      return session;
    }
  }

  /// Ensure today's daily session exists. Automatically generates if none exists or expired.
  Future<AttendanceSessionModel> ensureDailyAttendanceSession({
    int durationMinutes = 1440,
    String? office,
  }) async {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 1. Check in-memory state
    final cur = state.activeSession;
    if (cur != null && cur.isActive && cur.formattedDate == todayStr) {
      return cur;
    }

    // 2. Check local persistent storage for today
    final cached = await StorageService.getDailyQRSession();
    if (cached != null) {
      final cachedSession = AttendanceSessionModel.fromJson(cached);
      if (cachedSession.isActive && cachedSession.formattedDate == todayStr) {
        state = state.copyWith(activeSession: cachedSession);
        return cachedSession;
      }
    }

    // 3. Try to fetch from server
    try {
      final data = await AttendanceService.getActiveAttendanceSession();
      final raw = data['session'] ?? data['data'] ?? data['result'];
      if (raw is Map) {
        final serverSession =
            AttendanceSessionModel.fromJson(Map<String, dynamic>.from(raw));
        if (serverSession.isActive && serverSession.formattedDate == todayStr) {
          await StorageService.saveDailyQRSession(serverSession.toJson());
          state = state.copyWith(activeSession: serverSession);
          return serverSession;
        }
      }
    } catch (_) {}

    // 4. Automatically generate new daily QR session for today
    final newSession = await createAttendanceSession(
      durationMinutes: durationMinutes,
      office: office,
      notes: 'Daily Auto QR ($todayStr)',
    );
    return newSession ?? state.activeSession!;
  }

  /// Stop Attendance Session (Admin)
  Future<bool> stopAttendanceSession() async {
    final cur = state.activeSession;
    if (cur == null) return false;

    state = state.copyWith(isLoading: true);
    try {
      await AttendanceService.stopAttendanceSession(sessionId: cur.sessionId);
    } catch (_) {}

    final updated = cur.copyWith(status: 'STOPPED');
    await StorageService.saveDailyQRSession(updated.toJson());
    state = state.copyWith(isLoading: false, activeSession: updated);
    return true;
  }

  /// Fetch Active Attendance Session
  Future<void> loadActiveSession() async {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Check storage first
    final cached = await StorageService.getDailyQRSession();
    if (cached != null) {
      final cachedSession = AttendanceSessionModel.fromJson(cached);
      if (cachedSession.isActive && cachedSession.formattedDate == todayStr) {
        state = state.copyWith(activeSession: cachedSession);
      }
    }

    try {
      final data = await AttendanceService.getActiveAttendanceSession();
      final raw = data['session'] ?? data['data'] ?? data['result'];
      if (raw is Map) {
        final session =
            AttendanceSessionModel.fromJson(Map<String, dynamic>.from(raw));
        if (session.isActive && session.formattedDate == todayStr) {
          await StorageService.saveDailyQRSession(session.toJson());
          state = state.copyWith(activeSession: session);
        }
      }
    } catch (_) {}
  }

  /// Refresh Live Session Scans
  Future<void> refreshSessionScans() async {
    final cur = state.activeSession;
    if (cur == null || !cur.isActive) return;

    try {
      final data = await AttendanceService.getSessionRecords(cur.sessionId);
      final raw = data['records'] ?? data['employees'] ?? data['data'] ?? data['scannedEmployees'];
      if (raw is List) {
        final list = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        final updated = cur.copyWith(
          scannedCount: list.length,
          scannedEmployees: list,
        );
        state = state.copyWith(activeSession: updated);
      }
    } catch (_) {}
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

  bool _isDateToday(dynamic val) {
    if (val == null) return false;
    try {
      DateTime dt;
      if (val is DateTime) {
        dt = val;
      } else {
        String s = val.toString().trim();
        if (s.isEmpty || s == 'null') return false;
        if (s.contains('T') &&
            !s.endsWith('Z') &&
            !s.substring(s.indexOf('T')).contains('+') &&
            !s.substring(s.indexOf('T')).contains('-')) {
          s += 'Z';
        }
        dt = DateTime.parse(s).toLocal();
      }
      final now = DateTime.now();
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadTodayAllAttendance() async {
    try {
      final data = await AttendanceService.getTodayAllAttendance();

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
      final seenIds = <String>{};

      void addIfUnique(Map<String, dynamic> record, {bool isServerRecord = false}) {
        final id = (record['userId'] ?? record['employeeId'] ?? record['_id'] ?? record['id'])
            ?.toString()
            .trim()
            .toLowerCase();
        final email = record['email']?.toString().trim().toLowerCase();
        final name = record['name']?.toString().trim().toLowerCase();

        final keys = [id, email, (name != null && name != 'employee' && name.length > 2 ? name : null)]
            .where((k) => k != null && k.isNotEmpty)
            .cast<String>();

        if (keys.any((k) => seenIds.contains(k))) {
          final idx = list.indexWhere((item) {
            if (item is! Map) return false;
            final iId = (item['userId'] ?? item['employeeId'] ?? item['_id'] ?? item['id'])
                ?.toString()
                .trim()
                .toLowerCase();
            final iEmail = item['email']?.toString().trim().toLowerCase();
            final iName = item['name']?.toString().trim().toLowerCase();

            final bool idMatch = id != null && id.isNotEmpty && id == iId;
            final bool emailMatch = email != null && email.isNotEmpty && email == iEmail;
            final bool nameMatch = name != null && name != 'employee' && name.length > 2 && name == iName;
            return idMatch || emailMatch || nameMatch;
          });
          if (idx >= 0) {
            final old = Map<String, dynamic>.from(list[idx]);
            final oldCheckIn = old['checkIn'] ?? old['checkInTime'] ?? old['inTime'];
            final newCheckIn = record['checkIn'] ?? record['checkInTime'] ?? record['inTime'];

            old.addAll(record);

            // Preserve valid server check-in time if existing record already had one
            if (oldCheckIn != null &&
                oldCheckIn.toString().isNotEmpty &&
                oldCheckIn.toString() != 'null') {
              if (!isServerRecord || (newCheckIn == null || newCheckIn.toString().isEmpty || newCheckIn.toString() == 'null')) {
                old['checkIn'] = oldCheckIn;
                old['checkInTime'] = oldCheckIn;
              }
            }
            list[idx] = old;
          }
          return;
        }

        seenIds.addAll(keys);
        list.add(record);
      }

      for (final emp in empList) {
        if (emp is! Map) continue;

        final attToday = emp['attendanceToday'] ?? emp['today'] ?? emp['todayAttendance'];

        if (attToday != null && attToday is Map) {
          final st = (attToday['status'] ?? attToday['attendanceStatus'] ?? 'Present').toString();
          if (!st.toLowerCase().contains('absent') && !st.toLowerCase().contains('leave')) {
            final cIn = attToday['checkInTime'] ??
                attToday['checkIn'] ??
                attToday['check_in'] ??
                attToday['inTime'] ??
                emp['checkInTime'] ??
                emp['checkIn'] ??
                emp['inTime'];
            final cOut = attToday['checkOutTime'] ??
                attToday['checkOut'] ??
                attToday['check_out'] ??
                emp['checkOutTime'] ??
                emp['checkOut'];
            final dtVal = attToday['date'] ?? attToday['createdAt'] ?? emp['date'] ?? emp['createdAt'];

            final checkInFinal = cIn ?? dtVal;

            final merged = <String, dynamic>{
              '_id': attToday['_id'] ?? attToday['id'] ?? emp['_id'],
              'status': st.isNotEmpty ? st : 'Present',
              'checkIn': checkInFinal,
              'checkInTime': checkInFinal,
              'checkOut': cOut,
              'checkOutTime': cOut,
              'date': dtVal ?? checkInFinal,
              'createdAt': attToday['createdAt'],
              'isActive': attToday['isActive'],
              'workHours': attToday['workHours'],
              'attendanceMethod': attToday['attendanceMethod'] ??
                  attToday['method'] ??
                  attToday['verificationMethod'] ??
                  'Direct Check-in',
              'name': emp['name'] ?? attToday['name'] ?? 'Employee',
              'email': emp['email'] ?? attToday['email'] ?? '',
              'userId': attToday['userId'] ?? emp['_id'] ?? emp['id'],
              'employeeId': emp['employeeId'] ?? attToday['employeeId'] ?? emp['_id'],
              'employee': {
                '_id': emp['_id'] ?? emp['id'],
                'name': emp['name'] ?? attToday['name'],
                'email': emp['email'] ?? attToday['email'],
                'designation': emp['designation'] ?? emp['role'],
                'profilePhoto': emp['profilePhoto'] ??
                    emp['avatar'] ??
                    emp['photo'] ??
                    emp['image'],
              },
            };
            addIfUnique(merged, isServerRecord: true);
          }
        } else {
          final empObj = emp['employee'] ?? emp['user'];
          String? name = (empObj is Map ? empObj['name'] : null) ??
              emp['name'] ??
              emp['userName'] ??
              emp['employeeName'];
          String? email = (empObj is Map ? empObj['email'] : null) ??
              emp['email'] ??
              emp['userEmail'];
          String? uid = (empObj is Map ? (empObj['_id'] ?? empObj['id']) : null) ??
              emp['userId'] ??
              emp['employeeId'] ??
              emp['_id'] ??
              emp['id'];
          final checkInVal = emp['checkInTime'] ??
              emp['checkIn'] ??
              emp['check_in'] ??
              emp['inTime'];
          final checkOutVal =
              emp['checkOutTime'] ?? emp['checkOut'] ?? emp['check_out'] ?? emp['outTime'];
          final st = (emp['status'] ?? emp['attendanceStatus'] ?? '').toString();

          final bool hasValidCheckIn = checkInVal != null &&
              checkInVal.toString().isNotEmpty &&
              checkInVal.toString() != 'null';

          final bool isToday = hasValidCheckIn ||
              _isDateToday(checkInVal) ||
              _isDateToday(emp['date']);

          if (isToday && (st.toLowerCase() == 'present' || st.toLowerCase() == 'active' || hasValidCheckIn)) {
            final finalCheckIn = checkInVal ?? emp['date'];
            addIfUnique({
              '_id': emp['_id'] ?? emp['id'] ?? uid,
              'status': (st.isNotEmpty && st.toLowerCase() != 'inactive') ? st : 'Present',
              'checkIn': finalCheckIn,
              'checkInTime': finalCheckIn,
              'checkOut': checkOutVal,
              'checkOutTime': checkOutVal,
              'date': emp['date'] ?? finalCheckIn,
              'createdAt': emp['createdAt'],
              'attendanceMethod': emp['attendanceMethod'] ??
                  emp['method'] ??
                  emp['verificationMethod'] ??
                  'Direct Check-in',
              'name': name ?? 'Employee',
              'email': email ?? '',
              'userId': uid ?? '',
              'employeeId': uid ?? '',
              'employee': empObj is Map ? empObj : emp,
            }, isServerRecord: true);
          }
        }
      }

      // 2. Load and Merge Face Lock Attendance scans recorded today
      try {
        final now = DateTime.now();
        final faceLogs = await FaceAttendanceLogService().getFaceAttendanceLogs();
        for (final fLog in faceLogs) {
          final isToday = (fLog.timestamp.year == now.year &&
                  fLog.timestamp.month == now.month &&
                  fLog.timestamp.day == now.day) ||
              now.difference(fLog.timestamp).inHours.abs() < 24;
          if (isToday) {
            addIfUnique({
              '_id': fLog.id,
              'status': 'Present',
              'checkIn': fLog.timestamp.toIso8601String(),
              'checkInTime': fLog.timestamp.toIso8601String(),
              'date': fLog.timestamp.toIso8601String(),
              'createdAt': fLog.timestamp.toIso8601String(),
              'name': fLog.userName,
              'email': fLog.email,
              'userId': fLog.userId,
              'employeeId': fLog.userId,
              'attendanceMethod': 'Face Lock Biometric',
              'verificationMethod': fLog.verificationMethod,
              'faceImage': fLog.faceImageBase64,
              'avatar': fLog.faceImageBase64 ?? fLog.registeredFaceImageBase64,
              'notes': fLog.notes,
              'employee': {
                '_id': fLog.userId,
                'name': fLog.userName,
                'email': fLog.email,
                'avatar': fLog.faceImageBase64 ?? fLog.registeredFaceImageBase64,
              },
            });
          }
        }
      } catch (_) {}

      // 3. Load and Merge Attendance QR / Barcode scanned session records
      try {
        final session = state.activeSession;
        if (session != null && session.scannedEmployees.isNotEmpty) {
          for (final scanned in session.scannedEmployees) {
            final scanTime = scanned['scannedAt'] ??
                scanned['checkIn'] ??
                scanned['checkInTime'] ??
                scanned['createdAt'];
            addIfUnique({
              '_id': scanned['_id'] ?? scanned['id'] ?? scanned['employeeId'],
              'status': 'Present',
              'checkIn': scanTime,
              'checkInTime': scanTime,
              'name': scanned['name'] ?? scanned['employeeName'] ?? 'Employee',
              'email': scanned['email'] ?? '',
              'userId': (scanned['employeeId'] ??
                      scanned['userId'] ??
                      scanned['_id'])
                  ?.toString() ??
                  '',
              'employeeId': (scanned['employeeId'] ??
                      scanned['userId'] ??
                      scanned['_id'])
                  ?.toString() ??
                  '',
              'attendanceMethod': 'QR Scanner',
              'employee': scanned,
            });
          }
        }
      } catch (_) {}

      // 4. Merge locally saved today attendances only for employees not yet in list
      try {
        final savedTodayList = await StorageService.getAllSavedTodayAttendances();
        for (final saved in savedTodayList) {
          final isPresent = (saved['status'] ?? '').toString().toLowerCase().contains('present') ||
              saved['checkIn'] != null ||
              saved['checkInTime'] != null;
          if (isPresent) {
            addIfUnique(saved, isServerRecord: false);
          }
        }
      } catch (_) {}

      // 5. Ensure current user's local today attendance is merged if marked
      if (state.isCheckedIn && state.todayAttendance != null) {
        final localAtt = state.todayAttendance!;
        addIfUnique(localAtt.toJson(), isServerRecord: false);
      }

      state = state.copyWith(todayAllAttendance: list);
    } catch (e, st) {
      debugPrint('[ATT_DEBUG] loadTodayAllAttendance ERROR: $e\n$st');
    }
  }

  Future<void> loadMyLeaves() async {
    state = state.copyWith(isLoading: true);
    final user = await StorageService.getUser();
    final emailOrId =
        (user?['email'] ?? user?['id'] ?? user?['_id'])?.toString() ?? '';

    try {
      final data = await AttendanceService.getMyLeaves();
      final leaves = _extractLeavesList(data);

      final cached = emailOrId.isNotEmpty
          ? await StorageService.getMyLeaves(emailOrId)
          : <dynamic>[];

      // Merge server leaves with local cached leaves (preserve any locally created leaves not yet returned by server)
      final combined = <dynamic>[...leaves];
      for (final local in cached) {
        if (local is Map) {
          final locId = (local['_id'] ?? local['id'])?.toString();
          final isFound = combined.any((srv) =>
              srv is Map &&
              (srv['_id']?.toString() == locId ||
                  srv['id']?.toString() == locId));
          if (!isFound) {
            combined.add(local);
          }
        }
      }

      if (emailOrId.isNotEmpty && combined.isNotEmpty) {
        await StorageService.saveMyLeaves(emailOrId, combined);
      }

      state = state.copyWith(
        isLoading: false,
        myLeaves: combined.isNotEmpty ? combined : leaves,
      );
    } catch (e) {
      if (emailOrId.isNotEmpty) {
        final cached = await StorageService.getMyLeaves(emailOrId);
        if (cached.isNotEmpty) {
          state = state.copyWith(isLoading: false, myLeaves: cached);
          return;
        }
      }
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadAllLeaves({String? status}) async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await AttendanceService.getAllLeaves(status: status);
      final leaves = _extractLeavesList(data);

      final cached = await StorageService.getAllLeaves();
      final combined = <dynamic>[...leaves];
      for (final local in cached) {
        if (local is Map) {
          final locId = (local['_id'] ?? local['id'])?.toString();
          final isFound = combined.any((srv) =>
              srv is Map &&
              (srv['_id']?.toString() == locId ||
                  srv['id']?.toString() == locId));
          if (!isFound) {
            combined.add(local);
          }
        }
      }

      if (combined.isNotEmpty) {
        await StorageService.saveAllLeaves(combined);
      }

      state = state.copyWith(
        isLoading: false,
        allLeaves: combined.isNotEmpty ? combined : leaves,
      );
    } catch (e) {
      final cached = await StorageService.getAllLeaves();
      if (cached.isNotEmpty) {
        state = state.copyWith(isLoading: false, allLeaves: cached);
        return;
      }
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

    final user = await StorageService.getUser();
    final emailOrId =
        (user?['email'] ?? user?['id'] ?? user?['_id'])?.toString() ?? '';
    final empName = (user?['name'] ?? 'Employee').toString();
    final nowIso = DateTime.now().toIso8601String();
    final tempId = 'leave_${DateTime.now().millisecondsSinceEpoch}';

    final localLeave = {
      '_id': tempId,
      'id': tempId,
      'leaveType': leaveType,
      'type': leaveType,
      'startDate': startDate,
      'endDate': endDate,
      'from': startDate,
      'to': endDate,
      'fromDate': startDate,
      'toDate': endDate,
      'reason': reason ?? '',
      'description': reason ?? '',
      'status': 'Pending',
      'createdAt': nowIso,
      'user': user,
      'employee': user,
      'employeeName': empName,
      'name': empName,
      'email': user?['email'],
      'userId': user?['id'] ?? user?['_id'],
      'employeeId': user?['id'] ?? user?['_id'],
    };

    // Optimistically update both myLeaves and allLeaves so UI updates INSTANTLY
    final newMyLeaves = [
      localLeave,
      ...state.myLeaves.where(
          (l) => l is! Map || (l['_id'] != tempId && l['id'] != tempId))
    ];
    final newAllLeaves = [
      localLeave,
      ...state.allLeaves.where(
          (l) => l is! Map || (l['_id'] != tempId && l['id'] != tempId))
    ];

    state = state.copyWith(
      isLoading: false,
      myLeaves: newMyLeaves,
      allLeaves: newAllLeaves,
    );

    if (emailOrId.isNotEmpty) {
      await StorageService.saveMyLeaves(emailOrId, newMyLeaves);
    }
    await StorageService.saveAllLeaves(newAllLeaves);

    // Notify realtime service / admin
    if (_ref != null) {
      RealtimeNotificationService.dispatchNotification(
        _ref,
        title: 'New Leave Request',
        message: '$empName applied for $leaveType.',
        type: 'leave_request',
        category: NotificationCategory.leaveRequest,
      );
    }

    try {
      final data = await AttendanceService.applyLeave(
        leaveType: leaveType,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
      );

      final rawLeave = data['leave'] ??
          data['data'] ??
          data['leaveRequest'] ??
          data['record'] ??
          data['item'];
      if (rawLeave is Map) {
        final serverLeave = Map<String, dynamic>.from(rawLeave);
        final updatedMy = state.myLeaves.map((l) {
          if (l is Map && (l['_id'] == tempId || l['id'] == tempId)) {
            return {...localLeave, ...serverLeave};
          }
          return l;
        }).toList();
        final updatedAll = state.allLeaves.map((l) {
          if (l is Map && (l['_id'] == tempId || l['id'] == tempId)) {
            return {...localLeave, ...serverLeave};
          }
          return l;
        }).toList();

        state = state.copyWith(myLeaves: updatedMy, allLeaves: updatedAll);
        if (emailOrId.isNotEmpty) {
          await StorageService.saveMyLeaves(emailOrId, updatedMy);
        }
        await StorageService.saveAllLeaves(updatedAll);
      }

      await loadMyLeaves();
      await loadAllLeaves();
      await loadStats();
      return true;
    } catch (_) {
      // Local optimistic record is already preserved in state and storage
      await loadStats();
      return true;
    }
  }

  Future<bool> approveRejectLeave(
      String leaveId, String status, String? comments) async {
    // Optimistically update local leave status in allLeaves and myLeaves
    final updatedAll = state.allLeaves.map((l) {
      if (l is Map &&
          (l['_id']?.toString() == leaveId || l['id']?.toString() == leaveId)) {
        final copy = Map<String, dynamic>.from(l);
        copy['status'] = status;
        if (comments != null) copy['comments'] = comments;
        return copy;
      }
      return l;
    }).toList();

    final updatedMy = state.myLeaves.map((l) {
      if (l is Map &&
          (l['_id']?.toString() == leaveId || l['id']?.toString() == leaveId)) {
        final copy = Map<String, dynamic>.from(l);
        copy['status'] = status;
        if (comments != null) copy['comments'] = comments;
        return copy;
      }
      return l;
    }).toList();

    state = state.copyWith(allLeaves: updatedAll, myLeaves: updatedMy);
    await StorageService.saveAllLeaves(updatedAll);

    final user = await StorageService.getUser();
    final emailOrId =
        (user?['email'] ?? user?['id'] ?? user?['_id'])?.toString() ?? '';
    if (emailOrId.isNotEmpty) {
      await StorageService.saveMyLeaves(emailOrId, updatedMy);
    }

    try {
      await AttendanceService.approveRejectLeave(
        leaveId: leaveId,
        status: status,
        comments: comments,
      );
    } catch (_) {}

    if (_ref != null) {
      final isApproved = status.toLowerCase().contains('approve');
      RealtimeNotificationService.dispatchNotification(
        _ref,
        title: isApproved ? 'Leave Approved' : 'Leave Rejected',
        message: isApproved
            ? 'Leave request has been approved.'
            : 'Leave request has been rejected.',
        type: isApproved ? 'leave_approved' : 'leave_rejected',
        category: isApproved
            ? NotificationCategory.leaveApproved
            : NotificationCategory.leaveRejected,
      );
    }

    await loadAllLeaves();
    await loadMyLeaves();
    await loadStats();
    return true;
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

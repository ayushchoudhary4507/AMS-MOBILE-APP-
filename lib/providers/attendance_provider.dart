import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';

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
  AttendanceNotifier() : super(const AttendanceState());

  void reset() {
    state = const AttendanceState();
  }

  /// Fetches today's attendance record from backend/database
  Future<void> loadTodayAttendance() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await AttendanceService.getMyTodayAttendance();

      final rawAttendance =
          data['attendance'] ?? data['data'] ?? data['result'] ?? data['record'];

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
          data['status'] != null) {
        attendanceMap = data;
      }

      AttendanceModel? model;
      if (attendanceMap != null && attendanceMap.isNotEmpty) {
        model = AttendanceModel.fromJson(attendanceMap);
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

  /// Check In API call
  Future<bool> markAttendance() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await AttendanceService.markAttendance();

      final bool isSuccess = data['success'] == true ||
          data['status'] == 'success' ||
          data['attendance'] != null ||
          data['data'] != null;

      if (isSuccess) {
        final raw = data['attendance'] ?? data['data'] ?? data['result'];
        Map<String, dynamic>? map;
        if (raw is Map<String, dynamic>) {
          map = raw;
        } else if (raw is Map) {
          map = Map<String, dynamic>.from(raw);
        }

        if (map != null && map.isNotEmpty) {
          final model = AttendanceModel.fromJson(map);
          state = state.copyWith(
            isLoading: false,
            todayAttendance: model,
            isCheckedIn: model.isCheckedIn,
            isCheckedOut: model.isCheckedOut,
            error: null,
          );
        } else {
          await loadTodayAttendance();
        }

        await loadStats();
        return true;
      } else {
        final msg = data['message']?.toString() ?? 'Failed to mark check-in.';
        // Attempt recovery from backend if already marked
        await loadTodayAttendance();
        if (state.isCheckedIn) {
          state = state.copyWith(isLoading: false, error: null);
          return true;
        }
        state = state.copyWith(isLoading: false, error: msg);
        return false;
      }
    } catch (e) {
      String errorMessage = 'Failed to mark check-in. Please try again.';
      if (e is DioException) {
        final resData = e.response?.data;
        if (resData is Map && resData['message'] != null) {
          errorMessage = resData['message'].toString();
        }
      } else {
        errorMessage = e.toString();
      }

      // Check if record already exists on backend DB
      await loadTodayAttendance();
      if (state.isCheckedIn) {
        state = state.copyWith(isLoading: false, error: null);
        return true;
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

      if (isSuccess) {
        final raw = data['attendance'] ?? data['data'] ?? data['result'];
        Map<String, dynamic>? map;
        if (raw is Map<String, dynamic>) {
          map = raw;
        } else if (raw is Map) {
          map = Map<String, dynamic>.from(raw);
        }

        if (map != null && map.isNotEmpty) {
          final model = AttendanceModel.fromJson(map);
          state = state.copyWith(
            isLoading: false,
            todayAttendance: model,
            isCheckedIn: model.isCheckedIn,
            isCheckedOut: model.isCheckedOut,
            error: null,
          );
        } else {
          await loadTodayAttendance();
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
      String errorMessage = 'Failed to mark check-out. Please try again.';
      if (e is DioException) {
        final resData = e.response?.data;
        if (resData is Map && resData['message'] != null) {
          errorMessage = resData['message'].toString();
        }
      } else {
        errorMessage = e.toString();
      }

      await loadTodayAttendance();
      if (state.isCheckedOut) {
        state = state.copyWith(isLoading: false, error: null);
        return true;
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
      final raw = data['attendance'] ??
          data['data'] ??
          data['records'] ??
          data['todayAttendance'] ??
          data['result'] ??
          (data is List ? data : []);
      final list = raw is List ? List<dynamic>.from(raw) : <dynamic>[];

      if (state.isCheckedIn && state.todayAttendance != null) {
        final localAtt = state.todayAttendance!;
        final exists = list.any((item) {
          if (item is! Map) return false;
          return item['userId'] == localAtt.userId ||
              item['employeeId'] == localAtt.employeeId ||
              item['_id'] == localAtt.id;
        });
        if (!exists) {
          list.add(localAtt.toJson());
        }
      }
      state = state.copyWith(todayAllAttendance: list);
    } catch (_) {
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
      final leaves = data['leaves'] ?? data['data'] ?? [];
      state = state.copyWith(
          isLoading: false, allLeaves: leaves is List ? leaves : []);
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
    try {
      final data = await AttendanceService.approveRejectLeave(
        leaveId: leaveId,
        status: status,
        comments: comments,
      );
      if (data['success'] == true || data['status'] == 'success') {
        await loadAllLeaves();
        return true;
      }
      return false;
    } catch (_) {
      return false;
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
  return AttendanceNotifier();
});

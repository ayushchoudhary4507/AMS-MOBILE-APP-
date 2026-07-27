import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/attendance_service.dart';

class AttendanceState {
  final bool isLoading;
  final Map<String, dynamic>? todayAttendance;
  final List<dynamic> history;
  final Map<String, dynamic>? stats;
  final List<dynamic> myLeaves;
  final List<dynamic> allLeaves;
  final String? error;
  final bool isCheckedIn;
  final bool isCheckedOut;

  const AttendanceState({
    this.isLoading = false,
    this.todayAttendance,
    this.history = const [],
    this.stats,
    this.myLeaves = const [],
    this.allLeaves = const [],
    this.error,
    this.isCheckedIn = false,
    this.isCheckedOut = false,
  });

  AttendanceState copyWith({
    bool? isLoading,
    Map<String, dynamic>? todayAttendance,
    List<dynamic>? history,
    Map<String, dynamic>? stats,
    List<dynamic>? myLeaves,
    List<dynamic>? allLeaves,
    String? error,
    bool? isCheckedIn,
    bool? isCheckedOut,
  }) {
    return AttendanceState(
      isLoading: isLoading ?? this.isLoading,
      todayAttendance: todayAttendance ?? this.todayAttendance,
      history: history ?? this.history,
      stats: stats ?? this.stats,
      myLeaves: myLeaves ?? this.myLeaves,
      allLeaves: allLeaves ?? this.allLeaves,
      error: error ?? this.error,
      isCheckedIn: isCheckedIn ?? this.isCheckedIn,
      isCheckedOut: isCheckedOut ?? this.isCheckedOut,
    );
  }
}

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  AttendanceNotifier() : super(const AttendanceState());

  Future<void> loadTodayAttendance() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await AttendanceService.getMyTodayAttendance();
      final attendance = data['attendance'] ?? data['data'];
      bool checkedIn = false;
      bool checkedOut = false;
      if (attendance != null) {
        checkedIn = attendance['checkIn'] != null;
        checkedOut = attendance['checkOut'] != null;
      }
      state = state.copyWith(
        isLoading: false,
        todayAttendance: attendance is Map<String, dynamic> ? attendance : null,
        isCheckedIn: checkedIn,
        isCheckedOut: checkedOut,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> markAttendance() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await AttendanceService.markAttendance();
      if (data['success'] == true) {
        await loadTodayAttendance();
        return true;
      }
      state = state.copyWith(
          isLoading: false, error: data['message'] ?? 'Failed');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> checkOut() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await AttendanceService.checkOut();
      if (data['success'] == true) {
        await loadTodayAttendance();
        return true;
      }
      state = state.copyWith(
          isLoading: false, error: data['message'] ?? 'Failed');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> loadStats() async {
    try {
      final data = await AttendanceService.getAttendanceStats();
      state = state.copyWith(stats: data);
    } catch (e) {
      // ignore stats errors
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
      if (data['success'] == true) {
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
      if (data['success'] == true) {
        await loadAllLeaves();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
  return AttendanceNotifier();
});

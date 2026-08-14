import '../core/constants/api_constants.dart';
import 'api_service.dart';

class AttendanceService {
  // Mark attendance (Check-in)
  static Future<Map<String, dynamic>> markAttendance({
    String status = 'present',
    String? notes,
  }) async {
    // Backend mark endpoint expects empty payload {} or minimal notes
    final Map<String, dynamic> body = {};
    if (notes != null && notes.isNotEmpty) {
      body['notes'] = notes;
    }

    try {
      final response = await ApiService.post(
        ApiConstants.attendanceMark,
        data: body,
      );
      return ApiService.toMap(response.data);
    } catch (e) {
      // Fallback 1: Try /attendance/check-in
      try {
        final response = await ApiService.post(
          '/attendance/check-in',
          data: body,
        );
        return ApiService.toMap(response.data);
      } catch (_) {}

      // Fallback 2: Try /attendance/checkin
      try {
        final response = await ApiService.post(
          '/attendance/checkin',
          data: body,
        );
        return ApiService.toMap(response.data);
      } catch (_) {}

      rethrow;
    }
  }

  // Check out
  static Future<Map<String, dynamic>> checkOut() async {
    final Map<String, dynamic> body = {};

    try {
      final response = await ApiService.put(
        ApiConstants.attendanceCheckout,
        data: body,
      );
      return ApiService.toMap(response.data);
    } catch (e) {
      try {
        final response = await ApiService.post(
          ApiConstants.attendanceCheckout,
          data: body,
        );
        return ApiService.toMap(response.data);
      } catch (_) {}
      rethrow;
    }
  }

  // Get my today's attendance
  static Future<Map<String, dynamic>> getMyTodayAttendance() async {
    final response = await ApiService.get(ApiConstants.attendanceMyToday);
    return ApiService.toMap(response.data);
  }

  // Get today all attendance (Admin)
  static Future<Map<String, dynamic>> getTodayAllAttendance() async {
    try {
      final response = await ApiService.get(ApiConstants.attendanceToday);
      return ApiService.toMap(response.data);
    } catch (e) {
      try {
        final response = await ApiService.get(ApiConstants.attendanceTodayStatus);
        return ApiService.toMap(response.data);
      } catch (_) {}
      try {
        final response = await ApiService.get('/attendance/all');
        return ApiService.toMap(response.data);
      } catch (_) {}
      try {
        final response = await ApiService.get('/attendance/by-date');
        return ApiService.toMap(response.data);
      } catch (_) {}
      rethrow;
    }
  }

  // Get today status
  static Future<Map<String, dynamic>> getTodayAttendanceStatus() async {
    final response = await ApiService.get(ApiConstants.attendanceTodayStatus);
    return ApiService.toMap(response.data);
  }

  // Get attendance stats
  static Future<Map<String, dynamic>> getAttendanceStats() async {
    final response = await ApiService.get(ApiConstants.attendanceStats);
    return ApiService.toMap(response.data);
  }

  // Get calendar data
  static Future<Map<String, dynamic>> getCalendarData({
    int? month,
    int? year,
  }) async {
    final Map<String, dynamic> query = {};
    if (month != null) query['month'] = month;
    if (year != null) query['year'] = year;

    final response = await ApiService.get(
      ApiConstants.attendanceCalendar,
      queryParams: query.isNotEmpty ? query : null,
    );
    return ApiService.toMap(response.data);
  }

  // Get history by employeeId
  static Future<Map<String, dynamic>> getAttendanceHistory(
      String employeeId) async {
    final response =
        await ApiService.get('${ApiConstants.attendanceHistory}/$employeeId');
    return ApiService.toMap(response.data);
  }

  // Get by specific date (Admin)
  static Future<Map<String, dynamic>> getAttendanceByDate(String date) async {
    final response = await ApiService.get(
      ApiConstants.attendanceByDate,
      queryParams: {'date': date},
    );
    return ApiService.toMap(response.data);
  }

  // Admin mark attendance
  static Future<Map<String, dynamic>> adminMarkAttendance({
    required String employeeId,
    required String status,
    String? notes,
  }) async {
    final Map<String, dynamic> body = {
      'employeeId': employeeId,
      'status': status,
    };
    if (notes != null && notes.isNotEmpty) {
      body['notes'] = notes;
    }

    final response = await ApiService.post(
      ApiConstants.attendanceAdminMark,
      data: body,
    );
    return ApiService.toMap(response.data);
  }

  // LEAVE
  static Future<Map<String, dynamic>> applyLeave({
    required String leaveType,
    required String startDate,
    required String endDate,
    String? reason,
  }) async {
    final Map<String, dynamic> body = {
      'leaveType': leaveType,
      'type': leaveType,
      'startDate': startDate,
      'endDate': endDate,
      'from': startDate,
      'to': endDate,
      'fromDate': startDate,
      'toDate': endDate,
    };
    if (reason != null && reason.isNotEmpty) {
      body['reason'] = reason;
      body['description'] = reason;
      body['leaveReason'] = reason;
    }

    try {
      final response = await ApiService.post(
        ApiConstants.leaveApply,
        data: body,
      );
      return ApiService.toMap(response.data);
    } catch (e) {
      // Fallback 1: /attendance/leave
      try {
        final response = await ApiService.post('/attendance/leave', data: body);
        return ApiService.toMap(response.data);
      } catch (_) {}

      // Fallback 2: /leave/apply
      try {
        final response = await ApiService.post('/leave/apply', data: body);
        return ApiService.toMap(response.data);
      } catch (_) {}

      // Fallback 3: /leaves/apply
      try {
        final response = await ApiService.post('/leaves/apply', data: body);
        return ApiService.toMap(response.data);
      } catch (_) {}

      // Fallback 4: /leaves
      try {
        final response = await ApiService.post('/leaves', data: body);
        return ApiService.toMap(response.data);
      } catch (_) {}

      // Fallback 5: /leave
      try {
        final response = await ApiService.post('/leave', data: body);
        return ApiService.toMap(response.data);
      } catch (_) {}

      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getMyLeaves() async {
    try {
      final response = await ApiService.get(ApiConstants.leaveMyLeaves);
      return ApiService.toMap(response.data);
    } catch (e) {
      try {
        final response = await ApiService.get('/attendance/leave/my');
        return ApiService.toMap(response.data);
      } catch (_) {}
      try {
        final response = await ApiService.get('/attendance/my-leaves');
        return ApiService.toMap(response.data);
      } catch (_) {}
      try {
        final response = await ApiService.get('/leave/my-leaves');
        return ApiService.toMap(response.data);
      } catch (_) {}
      try {
        final response = await ApiService.get('/leaves/my-leaves');
        return ApiService.toMap(response.data);
      } catch (_) {}
      try {
        final response = await ApiService.get('/leaves/my');
        return ApiService.toMap(response.data);
      } catch (_) {}
      try {
        final response = await ApiService.get('/leave/my');
        return ApiService.toMap(response.data);
      } catch (_) {}
      try {
        final response = await ApiService.get('/leaves');
        return ApiService.toMap(response.data);
      } catch (_) {}
      try {
        final response = await ApiService.get('/leave');
        return ApiService.toMap(response.data);
      } catch (_) {}
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getAllLeaves({String? status}) async {
    final Map<String, dynamic> query = {};
    if (status != null && status.isNotEmpty) {
      query['status'] = status;
    }

    try {
      final response = await ApiService.get(
        ApiConstants.leaveAll,
        queryParams: query.isNotEmpty ? query : null,
      );
      return ApiService.toMap(response.data);
    } catch (e) {
      try {
        final response = await ApiService.get(
          '/attendance/leave/all',
          queryParams: query.isNotEmpty ? query : null,
        );
        return ApiService.toMap(response.data);
      } catch (_) {}
      try {
        final response = await ApiService.get(
          '/attendance/leaves',
          queryParams: query.isNotEmpty ? query : null,
        );
        return ApiService.toMap(response.data);
      } catch (_) {}
      try {
        final response = await ApiService.get(
          '/leaves/all',
          queryParams: query.isNotEmpty ? query : null,
        );
        return ApiService.toMap(response.data);
      } catch (_) {}
      try {
        final response = await ApiService.get(
          '/leave/all',
          queryParams: query.isNotEmpty ? query : null,
        );
        return ApiService.toMap(response.data);
      } catch (_) {}
      try {
        final response = await ApiService.get(
          '/leaves',
          queryParams: query.isNotEmpty ? query : null,
        );
        return ApiService.toMap(response.data);
      } catch (_) {}
      try {
        final response = await ApiService.get(
          '/leave',
          queryParams: query.isNotEmpty ? query : null,
        );
        return ApiService.toMap(response.data);
      } catch (_) {}
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getPendingLeavesCount() async {
    try {
      final response = await ApiService.get(ApiConstants.leavePendingCount);
      return ApiService.toMap(response.data);
    } catch (_) {
      try {
        final response = await ApiService.get('/attendance/leave/pending');
        return ApiService.toMap(response.data);
      } catch (_) {}
      try {
        final response = await ApiService.get('/leaves/pending-count');
        return ApiService.toMap(response.data);
      } catch (_) {}
      return {'count': 0};
    }
  }

  static Future<Map<String, dynamic>> approveRejectLeave({
    required String leaveId,
    required String status, // 'Approved' or 'Rejected'
    String? comments,
  }) async {
    final Map<String, dynamic> body = {
      'status': status,
      'action': status.toLowerCase(),
    };
    if (comments != null && comments.isNotEmpty) {
      body['comments'] = comments;
      body['reason'] = comments;
      body['remarks'] = comments;
    }

    try {
      final response = await ApiService.put(
        '${ApiConstants.leaveApprove}/$leaveId',
        data: body,
      );
      return ApiService.toMap(response.data);
    } catch (e) {
      try {
        final response = await ApiService.put(
          '/attendance/leave/status/$leaveId',
          data: body,
        );
        return ApiService.toMap(response.data);
      } catch (_) {}
      try {
        final response = await ApiService.put(
          '/leaves/approve/$leaveId',
          data: body,
        );
        return ApiService.toMap(response.data);
      } catch (_) {}
      try {
        final response = await ApiService.put(
          '/leaves/$leaveId/status',
          data: body,
        );
        return ApiService.toMap(response.data);
      } catch (_) {}
      try {
        final response = await ApiService.put(
          '/leaves/$leaveId',
          data: body,
        );
        return ApiService.toMap(response.data);
      } catch (_) {}
      try {
        final response = await ApiService.patch(
          '${ApiConstants.leaveApprove}/$leaveId',
          data: body,
        );
        return ApiService.toMap(response.data);
      } catch (_) {}
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> cancelLeave(String leaveId) async {
    try {
      final response =
          await ApiService.put('${ApiConstants.leaveCancel}/$leaveId');
      return ApiService.toMap(response.data);
    } catch (e) {
      try {
        final response =
            await ApiService.put('/leaves/$leaveId/cancel');
        return ApiService.toMap(response.data);
      } catch (_) {}
      try {
        final response =
            await ApiService.delete('${ApiConstants.leaveCancel}/$leaveId');
        return ApiService.toMap(response.data);
      } catch (_) {}
      rethrow;
    }
  }
}

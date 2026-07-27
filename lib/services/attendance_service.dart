import '../core/constants/api_constants.dart';
import 'api_service.dart';

class AttendanceService {
  // Mark attendance (Check-in)
  static Future<Map<String, dynamic>> markAttendance({
    String status = 'present',
    String? notes,
  }) async {
    final response = await ApiService.post(
      ApiConstants.attendanceMark,
      data: {'status': status, if (notes != null) 'notes': notes},
    );
    return response.data;
  }

  // Check out
  static Future<Map<String, dynamic>> checkOut() async {
    final response = await ApiService.put(ApiConstants.attendanceCheckout);
    return response.data;
  }

  // Get my today's attendance
  static Future<Map<String, dynamic>> getMyTodayAttendance() async {
    final response = await ApiService.get(ApiConstants.attendanceMyToday);
    return response.data;
  }

  // Get today all attendance (Admin)
  static Future<Map<String, dynamic>> getTodayAllAttendance() async {
    final response = await ApiService.get(ApiConstants.attendanceToday);
    return response.data;
  }

  // Get today status
  static Future<Map<String, dynamic>> getTodayAttendanceStatus() async {
    final response = await ApiService.get(ApiConstants.attendanceTodayStatus);
    return response.data;
  }

  // Get attendance stats
  static Future<Map<String, dynamic>> getAttendanceStats() async {
    final response = await ApiService.get(ApiConstants.attendanceStats);
    return response.data;
  }

  // Get calendar data
  static Future<Map<String, dynamic>> getCalendarData({
    int? month,
    int? year,
  }) async {
    final response = await ApiService.get(
      ApiConstants.attendanceCalendar,
      queryParams: {
        if (month != null) 'month': month,
        if (year != null) 'year': year,
      },
    );
    return response.data;
  }

  // Get history by employeeId
  static Future<Map<String, dynamic>> getAttendanceHistory(
      String employeeId) async {
    final response =
        await ApiService.get('${ApiConstants.attendanceHistory}/$employeeId');
    return response.data;
  }

  // Get by specific date (Admin)
  static Future<Map<String, dynamic>> getAttendanceByDate(String date) async {
    final response = await ApiService.get(
      ApiConstants.attendanceByDate,
      queryParams: {'date': date},
    );
    return response.data;
  }

  // Admin mark attendance
  static Future<Map<String, dynamic>> adminMarkAttendance({
    required String employeeId,
    required String status,
    String? notes,
  }) async {
    final response = await ApiService.post(
      ApiConstants.attendanceAdminMark,
      data: {
        'employeeId': employeeId,
        'status': status,
        if (notes != null) 'notes': notes,
      },
    );
    return response.data;
  }

  // LEAVE
  static Future<Map<String, dynamic>> applyLeave({
    required String leaveType,
    required String startDate,
    required String endDate,
    String? reason,
  }) async {
    final response = await ApiService.post(
      ApiConstants.leaveApply,
      data: {
        'leaveType': leaveType,
        'startDate': startDate,
        'endDate': endDate,
        if (reason != null) 'reason': reason,
      },
    );
    return response.data;
  }

  static Future<Map<String, dynamic>> getMyLeaves() async {
    final response = await ApiService.get(ApiConstants.leaveMyLeaves);
    return response.data;
  }

  static Future<Map<String, dynamic>> getAllLeaves({String? status}) async {
    final response = await ApiService.get(
      ApiConstants.leaveAll,
      queryParams: {if (status != null) 'status': status},
    );
    return response.data;
  }

  static Future<Map<String, dynamic>> getPendingLeavesCount() async {
    final response = await ApiService.get(ApiConstants.leavePendingCount);
    return response.data;
  }

  static Future<Map<String, dynamic>> approveRejectLeave({
    required String leaveId,
    required String status, // 'Approved' or 'Rejected'
    String? comments,
  }) async {
    final response = await ApiService.put(
      '${ApiConstants.leaveApprove}/$leaveId',
      data: {
        'status': status,
        if (comments != null) 'comments': comments,
      },
    );
    return response.data;
  }

  static Future<Map<String, dynamic>> cancelLeave(String leaveId) async {
    final response =
        await ApiService.put('${ApiConstants.leaveCancel}/$leaveId');
    return response.data;
  }
}

import '../core/constants/api_constants.dart';
import 'api_service.dart';

class EmployeeService {
  static Future<Map<String, dynamic>> getAll() async {
    final response = await ApiService.get(ApiConstants.employees);
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> getById(String id) async {
    final response = await ApiService.get('${ApiConstants.employees}/$id');
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> create(
      Map<String, dynamic> data) async {
    try {
      final response = await ApiService.post(ApiConstants.employees, data: data);
      return ApiService.toMap(response.data);
    } catch (e) {
      try {
        final response = await ApiService.post(ApiConstants.register, data: data);
        return ApiService.toMap(response.data);
      } catch (_) {}
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> data) async {
    final response =
        await ApiService.put('${ApiConstants.employees}/$id', data: data);
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> delete(String id) async {
    final response = await ApiService.delete('${ApiConstants.employees}/$id');
    return ApiService.toMap(response.data);
  }
}

class TaskService {
  static Future<Map<String, dynamic>> getAll() async {
    final response = await ApiService.get(ApiConstants.tasks);
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> data) async {
    final response =
        await ApiService.put('${ApiConstants.tasks}/$id', data: data);
    return ApiService.toMap(response.data);
  }
}

class NotificationService {
  static Future<Map<String, dynamic>> getAll() async {
    final response = await ApiService.get(ApiConstants.notifications);
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> markRead(String id) async {
    final response =
        await ApiService.put('${ApiConstants.notifications}/$id/read');
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> markAllRead() async {
    final response =
        await ApiService.put('${ApiConstants.notifications}/mark-all-read');
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> registerDeviceToken(String token) async {
    try {
      final response = await ApiService.post(
        ApiConstants.deviceToken,
        data: {
          'token': token,
          'platform': 'android', // Defaults to android; iOS tokens work with same endpoint
          // Legacy fields for compatibility with older endpoints
          'deviceToken': token,
          'fcmToken': token,
        },
      );
      return ApiService.toMap(response.data);
    } catch (_) {
      return {};
    }
  }

  static Future<void> unregisterDeviceToken(String token) async {
    try {
      await ApiService.delete(
        // ignore: prefer_interpolation_to_compose_strings
        ApiConstants.unregisterDeviceToken + '?token=' + Uri.encodeComponent(token),
      );
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> delete(String id) async {
    if (id.trim().isEmpty) return {};

    final candidateEndpoints = [
      '${ApiConstants.notifications}/$id',
      '${ApiConstants.notifications}/delete/$id',
      '${ApiConstants.notifications}/$id/delete',
      '/notifications/$id',
      '/notifications/delete/$id',
    ];

    for (final ep in candidateEndpoints) {
      try {
        final response = await ApiService.delete(ep);
        final map = ApiService.toMap(response.data);
        if (map.isNotEmpty || (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300)) {
          return map.isNotEmpty ? map : {'success': true};
        }
      } catch (_) {}
    }

    try {
      final response = await ApiService.post(
        '${ApiConstants.notifications}/delete',
        data: {'id': id, 'notificationId': id, '_id': id},
      );
      return ApiService.toMap(response.data);
    } catch (_) {}

    return {};
  }

  static Future<Map<String, dynamic>> sendNotification({
    required String title,
    required String message,
    required String type,
    String? recipientRole = 'admin',
    String? recipientId,
  }) async {
    final candidateEndpoints = [
      ApiConstants.notifications,
      '${ApiConstants.notifications}/create',
      '${ApiConstants.notifications}/send',
      '/notifications',
      '/notifications/send',
    ];

    final payload = <String, dynamic>{
      'title': title,
      'message': message,
      'type': type,
      'recipientRole': recipientRole ?? 'admin',
      'createdAt': DateTime.now().toIso8601String(),
    };
    if (recipientId != null) {
      payload['recipientId'] = recipientId;
    }

    for (final ep in candidateEndpoints) {
      try {
        final response = await ApiService.post(ep, data: payload);
        final map = ApiService.toMap(response.data);
        if (map.isNotEmpty ||
            (response.statusCode != null &&
                response.statusCode! >= 200 &&
                response.statusCode! < 300)) {
          return map.isNotEmpty ? map : {'success': true};
        }
      } catch (_) {}
    }
    return {};
  }
}

class AnalyticsService {
  static Future<Map<String, dynamic>> getOverview() async {
    try {
      final response = await ApiService.get('${ApiConstants.analytics}/dashboard');
      final map = ApiService.toMap(response.data);
      if (map.isNotEmpty) return map;
    } catch (_) {}
    try {
      final response = await ApiService.get('${ApiConstants.analytics}/overview');
      final map = ApiService.toMap(response.data);
      if (map.isNotEmpty) return map;
    } catch (_) {}
    return {};
  }

  static Future<Map<String, dynamic>> getDepartment() async {
    final response =
        await ApiService.get('${ApiConstants.analytics}/department');
    return ApiService.toMap(response.data);
  }
}

class SalaryService {
  static Future<Map<String, dynamic>> getMySalary({int? month, int? year}) async {
    final query = <String, dynamic>{};
    if (month != null) query['month'] = month;
    if (year != null) query['year'] = year;
    final response = await ApiService.get('${ApiConstants.salary}/my-salary', queryParams: query);
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> getAll({int? month, int? year}) async {
    final query = <String, dynamic>{};
    if (month != null) query['month'] = month;
    if (year != null) query['year'] = year;
    final response = await ApiService.get(ApiConstants.salary, queryParams: query);
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> calculateSalary(Map<String, dynamic> data) async {
    final response = await ApiService.post('${ApiConstants.salary}/calculate', data: data);
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> markAsPaid(String id) async {
    final response = await ApiService.put('${ApiConstants.salary}/$id/pay');
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> bulkCalculate(int month, int year) async {
    final response = await ApiService.post('${ApiConstants.salary}/bulk-calculate', data: {
      'month': month,
      'year': year,
    });
    return ApiService.toMap(response.data);
  }
}

class ReportService {
  static Future<Map<String, dynamic>> getAllMonthlyReports({int? month, int? year}) async {
    final query = <String, dynamic>{};
    if (month != null) query['month'] = month;
    if (year != null) query['year'] = year;
    final response = await ApiService.get('${ApiConstants.reports}/monthly', queryParams: query);
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> getMyReport({int? month, int? year}) async {
    final query = <String, dynamic>{};
    if (month != null) query['month'] = month;
    if (year != null) query['year'] = year;
    final response = await ApiService.get('${ApiConstants.reports}/my-report', queryParams: query);
    return ApiService.toMap(response.data);
  }
}

class ProjectService {
  static Future<Map<String, dynamic>> getAll() async {
    final response = await ApiService.get(ApiConstants.projects);
    return ApiService.toMap(response.data);
  }
}

class HolidayService {
  static Future<Map<String, dynamic>> getAll({int? year}) async {
    final query = <String, dynamic>{};
    if (year != null) query['year'] = year;
    final response = await ApiService.get(ApiConstants.holidays, queryParams: query);
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> createHoliday(Map<String, dynamic> data) async {
    final response = await ApiService.post(ApiConstants.holidays, data: data);
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> updateHoliday(String id, Map<String, dynamic> data) async {
    final response = await ApiService.put('${ApiConstants.holidays}/$id', data: data);
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> deleteHoliday(String id) async {
    final response = await ApiService.delete('${ApiConstants.holidays}/$id');
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> importHolidays(int year) async {
    final response = await ApiService.post('${ApiConstants.holidays}/import', data: {'year': year});
    return ApiService.toMap(response.data);
  }
}

class ShiftService {
  static Future<Map<String, dynamic>> getAll() async {
    final response = await ApiService.get(ApiConstants.shifts);
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> getAllAssignments() async {
    final response = await ApiService.get('${ApiConstants.shifts}/assignments');
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> getMyShifts() async {
    final response = await ApiService.get('${ApiConstants.shifts}/my-shifts');
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> createShift(Map<String, dynamic> data) async {
    final response = await ApiService.post('${ApiConstants.shifts}/create', data: data);
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> deleteShift(String id) async {
    final response = await ApiService.delete('${ApiConstants.shifts}/$id');
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> assignShift(Map<String, dynamic> data) async {
    final response = await ApiService.post('${ApiConstants.shifts}/assign', data: data);
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> removeAssignment(String id) async {
    final response = await ApiService.delete('${ApiConstants.shifts}/assignment/$id');
    return ApiService.toMap(response.data);
  }
}

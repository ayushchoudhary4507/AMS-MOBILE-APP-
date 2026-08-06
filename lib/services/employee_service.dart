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
        data: {'deviceToken': token, 'fcmToken': token, 'token': token},
      );
      return ApiService.toMap(response.data);
    } catch (_) {
      return {};
    }
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
}

class AnalyticsService {
  static Future<Map<String, dynamic>> getOverview() async {
    final response = await ApiService.get('${ApiConstants.analytics}/overview');
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> getDepartment() async {
    final response =
        await ApiService.get('${ApiConstants.analytics}/department');
    return ApiService.toMap(response.data);
  }
}

class SalaryService {
  static Future<Map<String, dynamic>> getMySalary() async {
    final response = await ApiService.get('${ApiConstants.salary}/my-salary');
    return ApiService.toMap(response.data);
  }

  static Future<Map<String, dynamic>> getAll() async {
    final response = await ApiService.get(ApiConstants.salary);
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
  static Future<Map<String, dynamic>> getAll() async {
    final response = await ApiService.get(ApiConstants.holidays);
    return ApiService.toMap(response.data);
  }
}

class ShiftService {
  static Future<Map<String, dynamic>> getAll() async {
    final response = await ApiService.get(ApiConstants.shifts);
    return ApiService.toMap(response.data);
  }
}

import '../core/constants/api_constants.dart';
import 'api_service.dart';

class EmployeeService {
  static Future<Map<String, dynamic>> getAll() async {
    final response = await ApiService.get(ApiConstants.employees);
    return response.data;
  }

  static Future<Map<String, dynamic>> getById(String id) async {
    final response = await ApiService.get('${ApiConstants.employees}/$id');
    return response.data;
  }

  static Future<Map<String, dynamic>> create(
      Map<String, dynamic> data) async {
    final response = await ApiService.post(ApiConstants.employees, data: data);
    return response.data;
  }

  static Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> data) async {
    final response =
        await ApiService.put('${ApiConstants.employees}/$id', data: data);
    return response.data;
  }

  static Future<Map<String, dynamic>> delete(String id) async {
    final response = await ApiService.delete('${ApiConstants.employees}/$id');
    return response.data;
  }
}

class TaskService {
  static Future<Map<String, dynamic>> getAll() async {
    final response = await ApiService.get(ApiConstants.tasks);
    return response.data;
  }

  static Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> data) async {
    final response =
        await ApiService.put('${ApiConstants.tasks}/$id', data: data);
    return response.data;
  }
}

class NotificationService {
  static Future<Map<String, dynamic>> getAll() async {
    final response = await ApiService.get(ApiConstants.notifications);
    return response.data;
  }

  static Future<Map<String, dynamic>> markRead(String id) async {
    final response =
        await ApiService.put('${ApiConstants.notifications}/$id/read');
    return response.data;
  }

  static Future<Map<String, dynamic>> markAllRead() async {
    final response =
        await ApiService.put('${ApiConstants.notifications}/mark-all-read');
    return response.data;
  }
}

class AnalyticsService {
  static Future<Map<String, dynamic>> getOverview() async {
    final response = await ApiService.get('${ApiConstants.analytics}/overview');
    return response.data;
  }

  static Future<Map<String, dynamic>> getDepartment() async {
    final response =
        await ApiService.get('${ApiConstants.analytics}/department');
    return response.data;
  }
}

class SalaryService {
  static Future<Map<String, dynamic>> getMySalary() async {
    final response = await ApiService.get('${ApiConstants.salary}/my-salary');
    return response.data;
  }

  static Future<Map<String, dynamic>> getAll() async {
    final response = await ApiService.get(ApiConstants.salary);
    return response.data;
  }
}

class ProjectService {
  static Future<Map<String, dynamic>> getAll() async {
    final response = await ApiService.get(ApiConstants.projects);
    return response.data;
  }
}

class HolidayService {
  static Future<Map<String, dynamic>> getAll() async {
    final response = await ApiService.get(ApiConstants.holidays);
    return response.data;
  }
}

class ShiftService {
  static Future<Map<String, dynamic>> getAll() async {
    final response = await ApiService.get(ApiConstants.shifts);
    return response.data;
  }
}

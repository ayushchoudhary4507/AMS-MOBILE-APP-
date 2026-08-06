import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/storage_service.dart';
import '../services/employee_service.dart';
import 'auth_provider.dart';

class EmployeeState {
  final bool isLoading;
  final List<dynamic> employees;
  final String? error;

  const EmployeeState({
    this.isLoading = false,
    this.employees = const [],
    this.error,
  });

  EmployeeState copyWith({
    bool? isLoading,
    List<dynamic>? employees,
    String? error,
  }) {
    return EmployeeState(
      isLoading: isLoading ?? this.isLoading,
      employees: employees ?? this.employees,
      error: error ?? this.error,
    );
  }
}

class EmployeeNotifier extends StateNotifier<EmployeeState> {
  EmployeeNotifier() : super(const EmployeeState());

  void reset() {
    state = const EmployeeState();
  }

  Future<void> loadEmployees() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await EmployeeService.getAll();
      final list = data['employees'] ?? data['data'] ?? data['records'] ?? data['items'] ?? [];
      List<dynamic> updatedList = [];
      if (list is List) {
        final currentUser = await StorageService.getUser();
        for (final emp in list) {
          if (emp is Map) {
            final empMap = Map<String, dynamic>.from(emp);
            final email = empMap['email']?.toString().trim().toLowerCase();
            final id = (empMap['_id'] ?? empMap['id'])?.toString().trim().toLowerCase();
            final name = empMap['name']?.toString().trim().toLowerCase();

            var avatar = extractAvatarUrl(empMap);

            if (avatar == null || avatar.isEmpty) {
              if (email != null && email.isNotEmpty) {
                avatar = await StorageService.getUserAvatar(email);
              }
              if ((avatar == null || avatar.isEmpty) && id != null && id.isNotEmpty) {
                avatar = await StorageService.getUserAvatar(id);
              }
              if ((avatar == null || avatar.isEmpty) && name != null && name.isNotEmpty) {
                avatar = await StorageService.getUserAvatar(name);
              }
            }

            if ((avatar == null || avatar.isEmpty) && currentUser != null) {
              final userEmail = currentUser['email']?.toString().trim().toLowerCase();
              final userId = (currentUser['_id'] ?? currentUser['id'])?.toString().trim().toLowerCase();
              final userName = currentUser['name']?.toString().trim().toLowerCase();
              final userAvatar = extractAvatarUrl(currentUser);

              if (userAvatar != null && userAvatar.isNotEmpty) {
                if ((email != null && email == userEmail) ||
                    (id != null && id == userId) ||
                    (name != null && userName != null && name == userName)) {
                  avatar = userAvatar;
                }
              }
            }

            if (avatar != null && avatar.isNotEmpty) {
              empMap['avatar'] = avatar;
              empMap['photo'] = avatar;
              empMap['profilePicture'] = avatar;
              empMap['image'] = avatar;
              if (email != null && email.isNotEmpty) {
                await StorageService.saveUserAvatar(email, avatar);
              }
            }
            updatedList.add(empMap);
          } else {
            updatedList.add(emp);
          }
        }
      }
      state = state.copyWith(
        isLoading: false,
        employees: updatedList,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> addEmployee(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await EmployeeService.create(data);
      final bool isSuccess = res['success'] == true ||
          res['status'] == 'success' ||
          res['employee'] != null ||
          res['user'] != null ||
          res['data'] != null;

      if (isSuccess) {
        await loadEmployees();
        return true;
      } else {
        final msg = res['message']?.toString() ?? 'Failed to create employee on server';
        state = state.copyWith(isLoading: false, error: msg);
        return false;
      }
    } catch (e) {
      String errorMessage = 'Failed to add employee on server.';
      if (e is DioException) {
        final resData = e.response?.data;
        if (resData is Map && resData['message'] != null) {
          errorMessage = resData['message'].toString();
        }
      } else {
        errorMessage = e.toString();
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    }
  }

  Future<bool> updateEmployee(String id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final avatar = extractAvatarUrl(data);
      final email = data['email']?.toString();
      if (avatar != null && avatar.isNotEmpty) {
        if (email != null && email.isNotEmpty) await StorageService.saveUserAvatar(email, avatar);
        await StorageService.saveUserAvatar(id, avatar);
      }
      await EmployeeService.update(id, data);
      await loadEmployees();
      return true;
    } catch (e) {
      final updatedList = state.employees.map((emp) {
        final empId = emp['_id']?.toString() ?? emp['id']?.toString();
        if (empId == id) {
          final merged = {...(emp is Map ? emp : {}), ...data};
          final avatar = extractAvatarUrl(merged);
          final email = merged['email']?.toString();
          if (avatar != null && avatar.isNotEmpty && email != null) {
            StorageService.saveUserAvatar(email, avatar);
          }
          return merged;
        }
        return emp;
      }).toList();
      state = state.copyWith(isLoading: false, employees: updatedList);
      return true;
    }
  }

  Future<bool> deleteEmployee(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await EmployeeService.delete(id);
      final updatedList = state.employees
          .where((e) => (e['_id']?.toString() ?? e['id']?.toString()) != id)
          .toList();
      state = state.copyWith(isLoading: false, employees: updatedList);
      return true;
    } catch (e) {
      final updatedList = state.employees
          .where((e) => (e['_id']?.toString() ?? e['id']?.toString()) != id)
          .toList();
      state = state.copyWith(isLoading: false, employees: updatedList);
      return true;
    }
  }
}

final employeeProvider =
    StateNotifierProvider<EmployeeNotifier, EmployeeState>((ref) {
  return EmployeeNotifier();
});

// Tasks Provider
class TaskState {
  final bool isLoading;
  final List<dynamic> tasks;
  final String? error;

  const TaskState({
    this.isLoading = false,
    this.tasks = const [],
    this.error,
  });

  TaskState copyWith({
    bool? isLoading,
    List<dynamic>? tasks,
    String? error,
  }) {
    return TaskState(
      isLoading: isLoading ?? this.isLoading,
      tasks: tasks ?? this.tasks,
      error: error ?? this.error,
    );
  }
}

class TaskNotifier extends StateNotifier<TaskState> {
  TaskNotifier() : super(const TaskState());

  Future<void> loadTasks() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await TaskService.getAll();
      final list = data['tasks'] ?? data['data'] ?? [];
      state = state.copyWith(
        isLoading: false,
        tasks: list is List ? list : [],
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final taskProvider = StateNotifierProvider<TaskNotifier, TaskState>((ref) {
  return TaskNotifier();
});

// Notification Provider
final notificationsProvider = FutureProvider<List<dynamic>>((ref) async {
  try {
    final data = await NotificationService.getAll();
    final list = data['notifications'] ?? data['data'] ?? [];
    return list is List ? list : [];
  } catch (_) {
    return [];
  }
});

// Holiday Provider
final holidaysProvider = FutureProvider<List<dynamic>>((ref) async {
  try {
    final data = await HolidayService.getAll();
    final list = data['holidays'] ?? data['data'] ?? [];
    return list is List ? list : [];
  } catch (_) {
    return [];
  }
});

// Salary Provider
final mySalaryProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final data = await SalaryService.getMySalary();
    return data.isNotEmpty ? data : null;
  } catch (e) {
    return null;
  }
});

final allSalaryProvider = FutureProvider<List<dynamic>>((ref) async {
  try {
    final data = await SalaryService.getAll();
    final list = data['salaries'] ?? data['data'] ?? [];
    return list is List ? list : [];
  } catch (_) {
    return [];
  }
});

// Projects Provider
final projectsProvider = FutureProvider<List<dynamic>>((ref) async {
  try {
    final data = await ProjectService.getAll();
    final list = data['projects'] ?? data['data'] ?? data['records'] ?? data['result'] ?? data['items'] ?? [];
    return list is List ? list : [];
  } catch (_) {
    return [];
  }
});

// Analytics Provider
final analyticsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final data = await AnalyticsService.getOverview();
    return data.isNotEmpty ? data : null;
  } catch (e) {
    return null;
  }
});

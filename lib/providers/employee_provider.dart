import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/employee_service.dart';

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

  Future<void> loadEmployees() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await EmployeeService.getAll();
      final list = data['employees'] ?? data['data'] ?? data ?? [];
      state = state.copyWith(
        isLoading: false,
        employees: list is List ? list : [],
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> deleteEmployee(String id) async {
    try {
      final data = await EmployeeService.delete(id);
      if (data['success'] == true) {
        await loadEmployees();
        return true;
      }
      return false;
    } catch (e) {
      return false;
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
  final data = await NotificationService.getAll();
  final list = data['notifications'] ?? data['data'] ?? [];
  return list is List ? list : [];
});

// Holiday Provider
final holidaysProvider = FutureProvider<List<dynamic>>((ref) async {
  final data = await HolidayService.getAll();
  final list = data['holidays'] ?? data['data'] ?? [];
  return list is List ? list : [];
});

// Salary Provider
final mySalaryProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final data = await SalaryService.getMySalary();
    return data;
  } catch (e) {
    return null;
  }
});

final allSalaryProvider = FutureProvider<List<dynamic>>((ref) async {
  final data = await SalaryService.getAll();
  final list = data['salaries'] ?? data['data'] ?? [];
  return list is List ? list : [];
});

// Projects Provider
final projectsProvider = FutureProvider<List<dynamic>>((ref) async {
  final data = await ProjectService.getAll();
  final list = data['projects'] ?? data['data'] ?? [];
  return list is List ? list : [];
});

// Analytics Provider
final analyticsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    return await AnalyticsService.getOverview();
  } catch (e) {
    return null;
  }
});

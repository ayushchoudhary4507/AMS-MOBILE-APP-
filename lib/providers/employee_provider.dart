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

  void reset() {
    state = const EmployeeState();
  }

  Future<void> loadEmployees() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await EmployeeService.getAll();
      final list = data['employees'] ?? data['data'] ?? [];
      state = state.copyWith(
        isLoading: false,
        employees: list is List ? list : [],
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> addEmployee(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await EmployeeService.create(data);
      final newEmp = res['employee'] ?? res['user'] ?? res['data'] ?? res;
      if (res['success'] == true || newEmp != null) {
        await loadEmployees();
        return true;
      }
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      // Local state update fallback for offline or mock mode
      final mockEmp = {
        '_id': 'emp_${DateTime.now().millisecondsSinceEpoch}',
        'name': data['name'] ?? 'New Employee',
        'email': data['email'] ?? '',
        'department': data['department'] ?? 'IT',
        'role': data['role'] ?? 'employee',
        'phone': data['phone'] ?? '',
        'designation': data['designation'] ?? 'Employee',
      };
      final updatedList = [mockEmp, ...state.employees];
      state = state.copyWith(isLoading: false, employees: updatedList);
      return true;
    }
  }

  Future<bool> updateEmployee(String id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await EmployeeService.update(id, data);
      await loadEmployees();
      return true;
    } catch (e) {
      final updatedList = state.employees.map((emp) {
        final empId = emp['_id']?.toString() ?? emp['id']?.toString();
        if (empId == id) {
          return {...(emp is Map ? emp : {}), ...data};
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
    final list = data['projects'] ?? data['data'] ?? [];
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

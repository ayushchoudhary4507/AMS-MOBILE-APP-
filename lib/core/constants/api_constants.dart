// API Constants
class ApiConstants {
  static const String baseUrl =
      'https://attendence-management-system1.onrender.com/api';

  // Auth
  static const String login = '/login';
  static const String adminLogin = '/admin/login';
  static const String register = '/register';
  static const String authSend = '/auth/send';
  static const String authVerify = '/auth/verify';
  static const String authResend = '/auth/resend';

  // Employees
  static const String employees = '/employees';

  // Attendance
  static const String attendanceMark = '/attendance/mark';
  static const String attendanceScan = '/attendance/scan';
  static const String attendanceQrCheckin = '/attendance/qr-checkin';
  static const String attendanceSessionCreate = '/attendance/session/create';
  static const String attendanceSessionStop = '/attendance/session/stop';
  static const String attendanceSessionActive = '/attendance/session/active';
  static const String attendanceSessionRecords = '/attendance/session';
  static const String attendanceCheckout = '/attendance/checkout';
  static const String attendanceMyToday = '/attendance/my-today';
  static const String attendanceToday = '/attendance/today';
  static const String attendanceTodayStatus = '/attendance/today-status';
  static const String attendanceStats = '/attendance/stats';
  static const String attendanceCalendar = '/attendance/calendar';
  static const String attendanceHistory = '/attendance/history';
  static const String attendanceByDate = '/attendance/by-date';
  static const String attendanceAdminMark = '/attendance/admin-mark';


  // Leave
  static const String leaveApply = '/attendance/leave/apply';
  static const String leaveMyLeaves = '/attendance/leave/my-leaves';
  static const String leaveAll = '/attendance/leave/all';
  static const String leavePendingCount = '/attendance/leave/pending-count';
  static const String leaveApprove = '/attendance/leave/approve';
  static const String leaveCancel = '/attendance/leave/cancel';

  // Tasks
  static const String tasks = '/tasks';

  // Notifications
  static const String notifications = '/notifications';
  static const String deviceToken = '/notifications/device-token';

  // Analytics
  static const String analytics = '/analytics';

  // Salary
  static const String salary = '/salary';

  // Projects
  static const String projects = '/projects';

  // Holidays
  static const String holidays = '/holidays';

  // Settings
  static const String settings = '/settings';

  // Dashboard Overview Configuration
  static const String dashboardConfig = '/dashboard-config';

  // Shifts
  static const String shifts = '/shifts';
}

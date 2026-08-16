import 'package:ams_mobile_app/core/constants/api_constants.dart';
import 'package:ams_mobile_app/models/attendance_model.dart';
import 'package:ams_mobile_app/providers/attendance_provider.dart';
import 'package:ams_mobile_app/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QR Attendance Constants & Endpoints', () {
    test('ApiConstants defines QR attendance checkin endpoint', () {
      expect(ApiConstants.attendanceQrCheckin, '/attendance/qr-checkin');
    });
  });

  group('LocationResult Model & Verification', () {
    test('LocationResult success creates valid coordinates', () {
      final loc = LocationResult.success(30.1234, 77.1234);
      expect(loc.isSuccess, isTrue);
      expect(loc.latitude, 30.1234);
      expect(loc.longitude, 77.1234);
      expect(loc.errorMessage, isNull);
    });

    test('LocationResult error handles permission denied gracefully', () {
      final loc = LocationResult.error(
        'Location permission was denied.',
        isPermissionDenied: true,
      );
      expect(loc.isSuccess, isFalse);
      expect(loc.isPermissionDenied, isTrue);
      expect(loc.errorMessage, contains('denied'));
    });

    test('LocationResult error handles service disabled gracefully', () {
      final loc = LocationResult.error(
        'Location services are disabled on your device.',
        isServiceDisabled: true,
      );
      expect(loc.isSuccess, isFalse);
      expect(loc.isServiceDisabled, isTrue);
    });
  });

  group('AttendanceModel Parsing for QR Check-in', () {
    test('AttendanceModel parses backend QR response correctly', () {
      final json = {
        '_id': 'att_123',
        'employeeId': 'emp_456',
        'date': '2026-08-14T09:30:00.000Z',
        'checkIn': '2026-08-14T09:30:00.000Z',
        'status': 'present',
        'workingHours': 0.0,
      };

      final model = AttendanceModel.fromJson(json);
      expect(model.id, 'att_123');
      expect(model.employeeId, 'emp_456');
      expect(model.isCheckedIn, isTrue);
      expect(model.status, 'present');
      expect(model.formattedCheckInTime, isNot('--:-- --'));
    });
  });

  group('AttendanceState & QR Checkin State Handling', () {
    test('AttendanceState default values', () {
      const state = AttendanceState();
      expect(state.isLoading, isFalse);
      expect(state.isCheckedIn, isFalse);
      expect(state.todayAttendance, isNull);
    });

    test('AttendanceState copyWith updates todayAttendance and isCheckedIn', () {
      const state = AttendanceState();
      final model = AttendanceModel(
        id: '1',
        checkIn: DateTime.now(),
        status: 'present',
      );
      final updated = state.copyWith(
        todayAttendance: model,
        isCheckedIn: true,
        isLoading: false,
      );

      expect(updated.isCheckedIn, isTrue);
      expect(updated.todayAttendance?.status, 'present');
      expect(updated.isLoading, isFalse);
    });
  });
}

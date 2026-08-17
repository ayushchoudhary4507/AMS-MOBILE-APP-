import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ams_mobile_app/core/constants/api_constants.dart';
import 'package:ams_mobile_app/models/attendance_session_model.dart';
import 'package:ams_mobile_app/providers/attendance_provider.dart';

void main() {
  group('AttendanceSessionModel Tests', () {
    test('AttendanceSessionModel creates active session and computes remaining time', () {
      final now = DateTime.now();
      final session = AttendanceSessionModel(
        sessionId: 'ATT-SESSION-TEST-001',
        token: 'sec-token-12345',
        status: 'ACTIVE',
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 10)),
        durationMinutes: 10,
        scannedCount: 2,
        scannedEmployees: [
          {'name': 'Ayush', 'checkInTime': '09:32 AM', 'status': 'Present'},
          {'name': 'Rahul', 'checkInTime': '09:34 AM', 'status': 'Present'},
        ],
      );

      expect(session.isActive, isTrue);
      expect(session.isExpired, isFalse);
      expect(session.scannedCount, equals(2));
      expect(session.formattedRemainingTime, isNotEmpty);

      // Verify QR JSON payload contains session details
      final payload = jsonDecode(session.qrPayloadJson);
      expect(payload['sessionId'], equals('ATT-SESSION-TEST-001'));
      expect(payload['token'], equals('sec-token-12345'));
      expect(payload['type'], equals('AMS_ATTENDANCE_QR'));
    });

    test('AttendanceSessionModel detects expired session', () {
      final now = DateTime.now();
      final expiredSession = AttendanceSessionModel(
        sessionId: 'ATT-SESSION-EXPIRED',
        token: 'sec-token-old',
        status: 'ACTIVE',
        createdAt: now.subtract(const Duration(minutes: 20)),
        expiresAt: now.subtract(const Duration(minutes: 10)),
        durationMinutes: 10,
      );

      expect(expiredSession.isActive, isFalse);
      expect(expiredSession.isExpired, isTrue);
      expect(expiredSession.formattedRemainingTime, equals('00:00'));
    });

    test('AttendanceSessionModel handles STOPPED status', () {
      final now = DateTime.now();
      final stoppedSession = AttendanceSessionModel(
        sessionId: 'ATT-SESSION-STOPPED',
        token: 'sec-token-stopped',
        status: 'STOPPED',
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 10)),
      );

      expect(stoppedSession.isActive, isFalse);
      expect(stoppedSession.isExpired, isTrue);
    });
  });

  group('Session Endpoints & State Tests', () {
    test('ApiConstants defines session and scan routes', () {
      expect(ApiConstants.attendanceScan, equals('/attendance/scan'));
      expect(ApiConstants.attendanceQrCheckin, equals('/attendance/qr-checkin'));
      expect(ApiConstants.attendanceSessionCreate, equals('/attendance/session/create'));
      expect(ApiConstants.attendanceSessionStop, equals('/attendance/session/stop'));
      expect(ApiConstants.attendanceSessionActive, equals('/attendance/session/active'));
    });

    test('AttendanceState supports activeSession', () {
      const state = AttendanceState();
      expect(state.activeSession, isNull);

      final now = DateTime.now();
      final session = AttendanceSessionModel(
        sessionId: 'ATT-123',
        token: 'token-xyz',
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 10)),
      );

      final updated = state.copyWith(activeSession: session);
      expect(updated.activeSession, isNotNull);
      expect(updated.activeSession!.sessionId, equals('ATT-123'));
    });
  });
}

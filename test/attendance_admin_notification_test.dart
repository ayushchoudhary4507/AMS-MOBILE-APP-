import 'package:ams_mobile_app/services/realtime_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Admin Attendance Real-time Notification Tests', () {
    test('parseCategory correctly identifies Check-In and Check-Out', () {
      expect(
        RealtimeNotificationService.parseCategory('attendance_checkin'),
        equals(NotificationCategory.attendanceCheckIn),
      );
      expect(
        RealtimeNotificationService.parseCategory('attendance_checkout'),
        equals(NotificationCategory.attendanceCheckOut),
      );
      expect(
        RealtimeNotificationService.parseCategory('check_in'),
        equals(NotificationCategory.attendanceCheckIn),
      );
      expect(
        RealtimeNotificationService.parseCategory('check_out'),
        equals(NotificationCategory.attendanceCheckOut),
      );
    });

    test('RealtimeNotificationService deduplication correctly catches duplicate events', () {
      const dedupKey = 'att_EMP001_in_30_Aug_2026';
      
      expect(RealtimeNotificationService.isDuplicateRecentlyShown(dedupKey), isFalse);
      RealtimeNotificationService.markAsShown(dedupKey);
      expect(RealtimeNotificationService.isDuplicateRecentlyShown(dedupKey), isTrue);
    });

    test('RealtimeNotificationItem maps fields and formats payload properly', () {
      final item = RealtimeNotificationItem(
        id: 'att_test_999',
        title: 'Check In: Sarah Connor',
        message: 'Sarah Connor (EMP102) marked Check In at 9:15 AM on 30 Aug 2026 via QR Code.',
        type: 'attendance_checkin',
        category: NotificationCategory.attendanceCheckIn,
        createdAt: DateTime(2026, 8, 30, 9, 15),
      );

      final map = item.toMap();
      expect(map['id'], equals('att_test_999'));
      expect(map['title'], equals('Check In: Sarah Connor'));
      expect(map['type'], equals('attendance_checkin'));
      expect(map['message'], contains('Sarah Connor (EMP102)'));
      expect(map['message'], contains('Check In'));
      expect(map['message'], contains('9:15 AM'));
    });
  });
}

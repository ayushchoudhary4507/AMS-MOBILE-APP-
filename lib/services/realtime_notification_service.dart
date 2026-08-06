import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../screens/shared/notifications_screen.dart';

enum NotificationCategory {
  attendanceCheckIn,
  attendanceCheckOut,
  leaveRequest,
  leaveApproved,
  leaveRejected,
  announcement,
  general,
}

class RealtimeNotificationItem {
  final String id;
  final String title;
  final String message;
  final String type;
  final NotificationCategory category;
  final String? referenceId;
  final DateTime createdAt;
  final bool read;

  RealtimeNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.category,
    this.referenceId,
    DateTime? createdAt,
    this.read = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'referenceId': referenceId,
      'createdAt': createdAt.toIso8601String(),
      'read': read,
      'isRead': read,
    };
  }
}

class RealtimeNotificationService {
  static final RealtimeNotificationService _instance =
      RealtimeNotificationService._internal();

  factory RealtimeNotificationService() => _instance;

  RealtimeNotificationService._internal();

  final _streamController = StreamController<RealtimeNotificationItem>.broadcast();
  Stream<RealtimeNotificationItem> get notificationStream => _streamController.stream;

  /// Dispatch a new real-time notification event
  static void dispatchNotification(
    dynamic ref, {
    required String title,
    required String message,
    required String type,
    required NotificationCategory category,
    String? referenceId,
    BuildContext? context,
  }) {
    final newId = 'notif_${DateTime.now().millisecondsSinceEpoch}';
    final item = RealtimeNotificationItem(
      id: newId,
      title: title,
      message: message,
      type: type,
      category: category,
      referenceId: referenceId,
    );

    // 1. Broadcast item to stream
    _instance._streamController.add(item);

    // 2. Append item to Riverpod Notification Screen state instantly
    try {
      ref.read(notifScreenProvider.notifier).prependRealtimeNotification(item.toMap());
    } catch (_) {}

    // 3. Show Foreground In-App Toast Banner if context is provided
    if (context != null && context.mounted) {
      showForegroundBanner(context, item);
    }
  }

  /// Displays an in-app banner for foreground notifications
  static void showForegroundBanner(
      BuildContext context, RealtimeNotificationItem item) {
    IconData iconData;
    Color iconColor;

    switch (item.category) {
      case NotificationCategory.attendanceCheckIn:
        iconData = Icons.login_rounded;
        iconColor = const Color(0xFF10B981);
        break;
      case NotificationCategory.attendanceCheckOut:
        iconData = Icons.logout_rounded;
        iconColor = const Color(0xFFF59E0B);
        break;
      case NotificationCategory.leaveRequest:
        iconData = Icons.event_note_rounded;
        iconColor = const Color(0xFF6366F1);
        break;
      case NotificationCategory.leaveApproved:
        iconData = Icons.check_circle_rounded;
        iconColor = const Color(0xFF10B981);
        break;
      case NotificationCategory.leaveRejected:
        iconData = Icons.cancel_rounded;
        iconColor = const Color(0xFFEF4444);
        break;
      default:
        iconData = Icons.notifications_active_rounded;
        iconColor = AppColors.primary;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(12),
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: iconColor.withValues(alpha: 0.4), width: 1.5),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.message,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: iconColor,
          onPressed: () {
            handleNotificationTap(context, item.toMap());
          },
        ),
      ),
    );
  }

  /// Tap Action Navigation logic based on Notification Type & Role
  static void handleNotificationTap(
      BuildContext context, Map<String, dynamic> notif) {
    final type = (notif['type'] ?? notif['category'])?.toString().toLowerCase() ?? '';
    final title = (notif['title'])?.toString().toLowerCase() ?? '';

    if (type.contains('attendance') || title.contains('attendance')) {
      context.go('/notifications');
    } else if (type.contains('leave') || title.contains('leave')) {
      context.go('/notifications');
    } else {
      context.go('/notifications');
    }
  }
}

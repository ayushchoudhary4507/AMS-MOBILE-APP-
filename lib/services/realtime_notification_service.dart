import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../main.dart';
import '../screens/shared/notifications_screen.dart';

enum NotificationCategory {
  userLogin,
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

  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _isLocalNotifInitialized = false;

  /// Initialize Native Local System Notifications with high importance channel
  static Future<void> initNativeNotifications() async {
    if (_isLocalNotifInitialized) return;
    try {
      const androidInitSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInitSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidInitSettings,
        iOS: darwinInitSettings,
        macOS: darwinInitSettings,
      );

      await _localNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          final context = rootNavigatorKey.currentContext;
          if (context != null && context.mounted) {
            context.go('/notifications');
          }
        },
      );

      const androidChannel = AndroidNotificationChannel(
        'ams_high_importance_channel',
        'AMS Attendance & Leave Notifications',
        description: 'Real-time System Notifications for AMS Mobile App',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidChannel);
        await androidPlugin.requestNotificationsPermission();
      }

      _isLocalNotifInitialized = true;
    } catch (_) {}
  }

  /// Show System Level Native Push Notification (Sound, Vibration, Status Bar)
  static Future<void> showNativeSystemNotification(
      RealtimeNotificationItem item) async {
    try {
      await initNativeNotifications();

      const androidDetails = AndroidNotificationDetails(
        'ams_high_importance_channel',
        'AMS Attendance & Leave Notifications',
        channelDescription: 'Real-time System Notifications for AMS Mobile App',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'AMS Notification',
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _localNotificationsPlugin.show(
        id,
        item.title,
        item.message,
        notificationDetails,
        payload: item.type,
      );
    } catch (_) {}
  }

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
    if (ref != null) {
      try {
        ref.read(notifScreenProvider.notifier).prependRealtimeNotification(item.toMap());
      } catch (_) {}
    }

    // 3. Show Top-Floating In-App Popup Card Dialog
    showTopNotificationPopup(context, item);

    // 4. Trigger Native System Phone Notification (Sound + Vibration + Status Bar Banner)
    showNativeSystemNotification(item);
  }

  /// Displays a prominent top-floating heads-up popup dialog card
  static void showTopNotificationPopup(
      BuildContext? context, RealtimeNotificationItem item) {
    final activeContext = context ?? rootNavigatorKey.currentContext;

    if (activeContext != null && activeContext.mounted) {
      IconData iconData;
      Color iconColor;

      switch (item.category) {
        case NotificationCategory.userLogin:
          iconData = Icons.person_pin_rounded;
          iconColor = const Color(0xFF6366F1);
          break;
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

      showGeneralDialog(
        context: activeContext,
        barrierDismissible: true,
        barrierLabel: 'Notification',
        barrierColor: Colors.black.withValues(alpha: 0.15),
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
        transitionBuilder: (dialogCtx, anim1, anim2, child) {
          final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);

          Timer(const Duration(seconds: 4), () {
            if (dialogCtx.mounted) {
              Navigator.of(dialogCtx, rootNavigator: true).pop();
            }
          });

          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -1.0),
              end: Offset.zero,
            ).animate(curve),
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTap: () {
                      if (dialogCtx.mounted) {
                        Navigator.of(dialogCtx, rootNavigator: true).pop();
                      }
                      handleNotificationTap(activeContext, item.toMap());
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: iconColor.withValues(alpha: 0.6),
                          width: 1.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: iconColor.withValues(alpha: 0.3),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                          const BoxShadow(
                            color: Colors.black54,
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(iconData, color: iconColor, size: 24),
                          ),
                          const SizedBox(width: 14),
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
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.message,
                                  style: const TextStyle(
                                    color: Color(0xFFCBD5E1),
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              if (dialogCtx.mounted) {
                                Navigator.of(dialogCtx, rootNavigator: true).pop();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white10,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFF94A3B8),
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
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

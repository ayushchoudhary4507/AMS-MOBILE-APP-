import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/storage_service.dart';
import '../main.dart';
import '../screens/shared/notifications_screen.dart';
import '../providers/auth_provider.dart';
import 'employee_service.dart';

const FirebaseOptions _fallbackFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyAamsMobileDefaultApiKey123456789',
  appId: '1:123456789012:android:abcdef1234567890',
  messagingSenderId: '123456789012',
  projectId: 'attendence-management-system1',
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: _fallbackFirebaseOptions);
    }
    debugPrint("Handling background FCM push message: \${message.messageId}");
  } catch (e) {
    debugPrint("Background FCM handler error: \$e");
  }
}

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
    required String message,
    required this.type,
    required this.category,
    this.referenceId,
    DateTime? createdAt,
    this.read = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        message = RealtimeNotificationService.sanitizeNotificationMessage(
            message, createdAt ?? DateTime.now());

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

  static bool _isFirebaseMessagingInitialized = false;

  /// Initialize Firebase Cloud Messaging (FCM) handlers
  static Future<void> initFirebaseMessaging() async {
    if (_isFirebaseMessagingInitialized) return;
    try {
      if (Firebase.apps.isEmpty) return;

      final messaging = FirebaseMessaging.instance;

      // Request permissions (Android 13+ & iOS)
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Present alert, badge, and sound in foreground
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 1. Foreground Message Handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        final senderId = (message.data['senderId'] ?? message.data['sender'])?.toString();
        final receiverId = (message.data['receiverId'] ?? message.data['receiver'])?.toString();
        final user = await StorageService.getUser();
        final currentUserId = (user?['_id'] ?? user?['id'] ?? user?['userId'])?.toString();

        if (senderId != null && currentUserId != null && senderId == currentUserId) {
          // Do NOT show notification to the sender who sent the message
          return;
        }
        if (receiverId != null && currentUserId != null && receiverId != currentUserId) {
          // Do NOT show notification meant for another recipient
          return;
        }

        final notification = message.notification;
        final title = notification?.title ?? message.data['title'] ?? 'AMS Notification';
        final body = notification?.body ?? message.data['message'] ?? message.data['body'] ?? '';
        final type = (message.data['type'] ?? 'general').toString();

        final rawTime = message.data['loginAt'] ??
            message.data['createdAt'] ??
            message.data['loginTimestampUtc'] ??
            message.data['timestamp'];
        DateTime? createdAt;
        if (rawTime != null && rawTime.toString().isNotEmpty) {
          try {
            String str = rawTime.toString().trim();
            if (str.contains('T') &&
                !str.endsWith('Z') &&
                !str.substring(str.indexOf('T')).contains('+') &&
                !str.substring(str.indexOf('T')).contains('-')) {
              str += 'Z';
            }
            createdAt = DateTime.parse(str);
          } catch (_) {}
        }

        final category = parseCategory(type);
        final item = RealtimeNotificationItem(
          id: message.messageId ?? 'fcm_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          message: body,
          type: type,
          category: category,
          createdAt: createdAt,
        );

        showTopNotificationPopup(null, item);
        showNativeSystemNotification(item);
      });

      // 2. Background Notification Opened App Handler
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final context = rootNavigatorKey.currentContext;
        if (context != null && context.mounted) {
          handleNotificationTap(context, message.data);
        }
      });

      // 3. Initial Message Handler (App launched from killed state)
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = rootNavigatorKey.currentContext;
          if (context != null && context.mounted) {
            handleNotificationTap(context, initialMessage.data);
          }
        });
      }

      // 4. Token Refresh Listener
      messaging.onTokenRefresh.listen((newToken) async {
        await StorageService.saveDeviceToken(newToken);
        await NotificationService.registerDeviceToken(newToken);
      });

      // 5. Retrieve Initial FCM Token
      try {
        final token = await messaging.getToken();
        if (token != null && token.isNotEmpty) {
          await StorageService.saveDeviceToken(token);
          await NotificationService.registerDeviceToken(token);
        }
      } catch (_) {}

      _isFirebaseMessagingInitialized = true;
    } catch (e) {
      debugPrint("FCM initialization warning: $e");
    }
  }

  static NotificationCategory parseCategory(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('login')) return NotificationCategory.userLogin;
    if (lower.contains('checkin') || lower.contains('check_in')) return NotificationCategory.attendanceCheckIn;
    if (lower.contains('checkout') || lower.contains('check_out')) return NotificationCategory.attendanceCheckOut;
    if (lower.contains('leave')) return NotificationCategory.leaveRequest;
    return NotificationCategory.general;
  }

  static OverlayEntry? _currentOverlay;

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
        fullScreenIntent: false,
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

  /// Dispatch a new real-time notification event with role validation
  static void dispatchNotification(
    dynamic ref, {
    required String title,
    required String message,
    required String type,
    required NotificationCategory category,
    String? referenceId,
    String? recipientRole,
    BuildContext? context,
    DateTime? createdAt,
  }) {
    // Role-based safety filter: ONLY ADMIN receives check-in, check-out, login, leave request notifications
    try {
      final authState = ref?.read(authProvider);
      final bool isAdmin = authState?.isAdmin ?? false;
      if (!isAdmin) {
        final lowerType = type.toLowerCase();
        if (lowerType.contains('login') ||
            lowerType.contains('checkin') ||
            lowerType.contains('checkout') ||
            lowerType.contains('attendance') ||
            lowerType.contains('leave_request')) {
          // Employee must NEVER receive self-action notifications
          return;
        }
      }
    } catch (_) {}

    final newId = 'notif_${DateTime.now().millisecondsSinceEpoch}';
    final item = RealtimeNotificationItem(
      id: newId,
      title: title,
      message: message,
      type: type,
      category: category,
      referenceId: referenceId,
      createdAt: createdAt,
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

  /// Displays a prominent top-floating heads-up popup dialog card without blocking or dimming the screen
  static void showTopNotificationPopup(
      BuildContext? context, RealtimeNotificationItem item) {
    final activeContext = context ?? rootNavigatorKey.currentContext;
    if (activeContext == null || !activeContext.mounted) return;

    _currentOverlay?.remove();
    _currentOverlay = null;

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

    final overlayState = Overlay.maybeOf(activeContext);
    if (overlayState == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {
                  entry.remove();
                  if (_currentOverlay == entry) _currentOverlay = null;
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.2),
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
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.message,
                              style: const TextStyle(
                                color: Colors.white70,
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
                ),
              ),
            ),
          ),
        );
      },
    );

    _currentOverlay = entry;
    overlayState.insert(entry);

    Timer(const Duration(seconds: 4), () {
      if (_currentOverlay == entry) {
        entry.remove();
        _currentOverlay = null;
      }
    });
  }

  /// Tap Action Navigation logic based on Notification Type & Role (Step 12)
  static void handleNotificationTap(
      BuildContext context, Map<String, dynamic> notif) {
    final type = (notif['type'] ?? notif['category'])?.toString().toLowerCase() ?? '';
    final title = (notif['title'])?.toString().toLowerCase() ?? '';

    if (type.contains('login') || title.contains('login')) {
      context.go('/admin/projects');
    } else if (type.contains('checkin') || type.contains('checkout') || type.contains('attendance') || title.contains('attendance')) {
      context.go('/notifications');
    } else if (type.contains('leave') || title.contains('leave')) {
      context.go('/notifications');
    } else {
      context.go('/notifications');
    }
  }

  /// Replaces embedded UTC time patterns (e.g. 3:36:00 PM) with exact local IST time (e.g. 9:06 PM)
  /// NOTE: Skips login notification messages — backend already embeds correct IST login time.
  static String sanitizeNotificationMessage(String message, dynamic rawTimestamp) {
    if (message.isEmpty) return message;

    // Login notification messages already contain the correct IST-formatted time
    // set by the backend (loginController.js) — do NOT overwrite them.
    final lowerMsg = message.toLowerCase();
    if (lowerMsg.contains('logged in at') || lowerMsg.contains('employee login')) {
      return message;
    }

    DateTime? dt;
    if (rawTimestamp != null) {
      try {
        if (rawTimestamp is DateTime) {
          dt = rawTimestamp.toLocal();
        } else {
          String str = rawTimestamp.toString().trim();
          if (str.isNotEmpty) {
            if (str.contains('T') &&
                !str.endsWith('Z') &&
                !str.substring(str.indexOf('T')).contains('+') &&
                !str.substring(str.indexOf('T')).contains('-')) {
              str += 'Z';
            }
            dt = DateTime.parse(str).toLocal();
          }
        }
      } catch (_) {}
    }
    dt ??= DateTime.now();

    final formattedTime = DateFormat('h:mm a').format(dt);
    final timeRegex = RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\s*(?:AM|PM|am|pm)?\b');

    if (timeRegex.hasMatch(message)) {
      return message.replaceAllMapped(timeRegex, (match) {
        final matchedStr = match.group(0) ?? '';
        if (matchedStr.contains(':')) {
          return formattedTime;
        }
        return matchedStr;
      });
    }

    return message;
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/constants/api_constants.dart';
import '../core/utils/storage_service.dart';
import 'realtime_notification_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  bool _isConnected = false;
  String? _currentUserId;

  // Stream Controllers
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _onlineUsersController = StreamController<Set<String>>.broadcast();
  final _userStatusController = StreamController<Map<String, dynamic>>.broadcast();
  final _dashboardConfigController = StreamController<dynamic>.broadcast();
  final _attendanceMarkedController = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Set<String>> get onlineUsersStream => _onlineUsersController.stream;
  Stream<Map<String, dynamic>> get userStatusStream => _userStatusController.stream;
  Stream<dynamic> get dashboardConfigStream => _dashboardConfigController.stream;
  Stream<Map<String, dynamic>> get attendanceMarkedStream => _attendanceMarkedController.stream;
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;

  Set<String> _onlineUserIds = {};
  Set<String> get onlineUserIds => _onlineUserIds;
  bool get isConnected => _isConnected;

  /// Initialize Socket.IO connection
  Future<void> initSocket() async {
    try {
      final user = await StorageService.getUser();
      final userId = (user?['_id'] ?? user?['id'] ?? user?['userId'])?.toString();
      if (userId == null || userId.isEmpty) return;

      _currentUserId = userId;

      if (_socket != null) {
        if (!_socket!.connected) {
          _socket!.connect();
        } else {
          _socket!.emit('join', userId);
          _onlineUsersController.add(Set<String>.from(_onlineUserIds));
        }
        return;
      }

      // Extract socket host URL (remove /api prefix)
      String socketUrl = ApiConstants.baseUrl;
      if (socketUrl.endsWith('/api')) {
        socketUrl = socketUrl.substring(0, socketUrl.length - 4);
      }

      _socket = io.io(
        socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(10)
            .setReconnectionDelay(2000)
            .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        debugPrint('⚡ Socket connected to $socketUrl');
        if (_currentUserId != null) {
          _socket!.emit('join', _currentUserId);
        }
      });

      _socket!.onReconnect((_) {
        _isConnected = true;
        debugPrint('⚡ Socket reconnected to $socketUrl');
        if (_currentUserId != null) {
          _socket!.emit('join', _currentUserId);
        }
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        debugPrint('💤 Socket disconnected');
      });

      // 1. Receive real-time message
      _socket!.on('receive_message', (data) {
        if (data is Map) {
          _messageController.add(Map<String, dynamic>.from(data));
        }
      });

      // 2. Receive typing indicator
      _socket!.on('typing', (data) {
        if (data is Map) {
          _typingController.add(Map<String, dynamic>.from(data));
        }
      });

      // 3. Receive list of current online users
      _socket!.on('online_users', (data) {
        if (data is List) {
          _onlineUserIds = data.map((e) => e.toString()).toSet();
          _onlineUsersController.add(Set<String>.from(_onlineUserIds));
        }
      });

      // 4. Receive user status change (online / offline / last seen)
      _socket!.on('user_status', (data) {
        if (data is Map) {
          final statusMap = Map<String, dynamic>.from(data);
          final String? uid = statusMap['userId']?.toString();
          final bool isOnline = statusMap['isOnline'] == true;

          if (uid != null) {
            if (isOnline) {
              _onlineUserIds.add(uid);
            } else {
              _onlineUserIds.remove(uid);
            }
            _onlineUsersController.add(Set<String>.from(_onlineUserIds));
            _userStatusController.add(statusMap);
          }
        }
      });

      // 5. Receive real-time dashboard configuration updates from website
      _socket!.on('dashboard_config_updated', (data) {
        debugPrint('⚡ Received dashboard_config_updated from socket: $data');
        _dashboardConfigController.add(data);
      });

      // 6. Receive live Attendance Marked from ANY method (Website / QR / Face / Mobile)
      _socket!.on('attendance_marked', (data) {
        debugPrint('⚡ Received attendance_marked from socket: $data');
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          _handleAttendanceMarkedEvent(map);
        }
      });

      // 7. Receive live Attendance Updated broadcast (update stream only, no duplicate popup)
      _socket!.on('attendance_updated', (data) {
        debugPrint('⚡ Received attendance_updated from socket: $data');
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          _attendanceMarkedController.add(map);
        }
      });

      // 8. Receive new notification event
      _socket!.on('newNotification', (data) {
        debugPrint('⚡ Received newNotification from socket: $data');
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          _handleNotificationEvent(map);
        }
      });

      _socket!.on('receive_notification', (data) {
        debugPrint('⚡ Received receive_notification from socket: $data');
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final notif = map['notification'] ?? map;
          if (notif is Map) {
            _handleNotificationEvent(Map<String, dynamic>.from(notif));
          }
        }
      });

    } catch (e) {
      debugPrint('Socket init error: $e');
    }
  }

  /// Handle attendance marked event and trigger floating in-app popup notification ONLY for Admin
  void _handleAttendanceMarkedEvent(Map<String, dynamic> data) async {
    try {
      // 1. Notify streams so all screens/charts can silently refresh data if needed
      _attendanceMarkedController.add(data);

      // 2. Strict Role-Based Check using backend user state
      final user = await StorageService.getUser();
      final role = (user?['role'] ?? await StorageService.getRole() ?? '').toString().trim().toLowerCase();
      final bool isAdmin = role == 'admin';

      // IF logged-in user's role == "admin" -> Show attendance popup notification
      // ELSE IF logged-in user's role == "employee" -> DO NOT show attendance popup notification
      if (!isAdmin) {
        debugPrint('Skipping attendance popup: User role is "$role", not "admin".');
        return;
      }

      final empData = data['employee'] is Map ? Map<String, dynamic>.from(data['employee']) : null;
      final String empDisplayId = (empData?['employeeId'] ?? data['employeeId'] ?? '').toString();
      final empName = (empData?['name'] ?? data['name'] ?? data['employeeName'] ?? 'Employee').toString();
      final action = (data['action'] ?? 'marked').toString();
      final method = (data['method'] ?? data['verificationMethod'] ?? data['attendanceType'] ?? 'Direct Check-In').toString();
      final rawMsg = (data['message'] ?? '').toString();
      final timeStr = (data['attendanceTime'] ?? '').toString();

      final String notifId = (data['id'] ?? data['_id'] ?? 'att_${DateTime.now().millisecondsSinceEpoch}').toString();

      // Deduplicate rapid duplicate events (e.g. from broadcast + direct notification)
      final String dedupKey = 'att_${empDisplayId.isNotEmpty ? empDisplayId : empName}_${action}_${timeStr.isNotEmpty ? timeStr : DateTime.now().minute}';
      if (RealtimeNotificationService.isDuplicateRecentlyShown(dedupKey) ||
          RealtimeNotificationService.isDuplicateRecentlyShown(notifId)) {
        debugPrint('Duplicate attendance notification suppressed: $dedupKey');
        return;
      }
      RealtimeNotificationService.markAsShown(dedupKey);
      RealtimeNotificationService.markAsShown(notifId);

      final String title = (data['title'] ?? (action.toLowerCase().contains('out') ? 'Clocked Out: $empName' : 'Attendance Marked: $empName')).toString();
      final String message = rawMsg.isNotEmpty
          ? rawMsg
          : '$empName${empDisplayId.isNotEmpty ? ' ($empDisplayId)' : ''} marked attendance via $method.';

      final bool isCheckOut = action.toLowerCase().contains('out') ||
          rawMsg.toLowerCase().contains('out') ||
          title.toLowerCase().contains('out');

      final category = isCheckOut
          ? NotificationCategory.attendanceCheckOut
          : NotificationCategory.attendanceCheckIn;

      final item = RealtimeNotificationItem(
        id: notifId,
        title: title,
        message: message,
        type: isCheckOut ? 'attendance_checkout' : 'attendance_checkin',
        category: category,
        createdAt: DateTime.now(),
      );

      // Show top-floating popup dialog ONLY to Admin users
      RealtimeNotificationService.showTopNotificationPopup(null, item);

      // Trigger native system vibration & sound ONLY to Admin users
      RealtimeNotificationService.showNativeSystemNotification(item);
    } catch (e) {
      debugPrint('Error handling attendance socket event: $e');
    }
  }

  /// Handle general/system notification event and trigger popup
  void _handleNotificationEvent(Map<String, dynamic> data) async {
    try {
      final user = await StorageService.getUser();
      final role = (user?['role'] ?? await StorageService.getRole() ?? '').toString().trim().toLowerCase();
      final bool isAdmin = role == 'admin';

      final type = (data['type'] ?? data['notificationType'] ?? 'general').toString().toLowerCase();
      final receiverRole = (data['receiverRole'] ?? '').toString().toLowerCase();

      final isAttendance = type.contains('attendance') || type == 'checkout';

      // Attendance notifications and admin-targeted alerts must ONLY be shown to Admins
      if ((isAttendance || receiverRole == 'admin') && !isAdmin) {
        debugPrint('Skipping admin-only notification popup for employee: type=$type, receiverRole=$receiverRole, userRole=$role');
        return;
      }

      final notifId = (data['_id'] ?? data['id'] ?? 'notif_${DateTime.now().millisecondsSinceEpoch}').toString();
      if (RealtimeNotificationService.isDuplicateRecentlyShown(notifId)) {
        debugPrint('Duplicate notification popup suppressed: $notifId');
        return;
      }
      RealtimeNotificationService.markAsShown(notifId);

      final title = (data['title'] ?? 'New Notification').toString();
      final message = (data['message'] ?? data['body'] ?? '').toString();
      final category = RealtimeNotificationService.parseCategory(type);

      final item = RealtimeNotificationItem(
        id: notifId,
        title: title,
        message: message,
        type: type,
        category: category,
        createdAt: DateTime.now(),
      );

      RealtimeNotificationService.showTopNotificationPopup(null, item);
      RealtimeNotificationService.showNativeSystemNotification(item);

      _notificationController.add(data);
    } catch (e) {
      debugPrint('Error handling notification socket event: $e');
    }
  }

  /// Send message via Socket
  void sendMessage(Map<String, dynamic> messageData) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('send_message', messageData);
    }
  }

  /// Emit typing status
  void sendTypingStatus(String receiverId, bool isTyping) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('typing', {
        'receiverId': receiverId,
        'isTyping': isTyping,
      });
    }
  }

  /// Disconnect socket
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
    }
  }
}

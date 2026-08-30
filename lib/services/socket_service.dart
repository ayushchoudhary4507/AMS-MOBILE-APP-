import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
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

  /// Helper to join rooms depending on user role
  void _joinRooms(String userId, bool isAdmin) {
    if (_socket == null || !_socket!.connected) return;

    debugPrint('[NOTIFICATION] Admin connection found: userId=$userId, isAdmin=$isAdmin');

    // Join personal user room
    _socket!.emit('join', userId);
    _socket!.emit('join_room', userId);
    _socket!.emit('joinRoom', userId);
    _socket!.emit('register', userId);
    _socket!.emit('authenticate', {'userId': userId, 'isAdmin': isAdmin});

    // If Admin, join all administrative notification rooms
    if (isAdmin) {
      _socket!.emit('join', 'admin');
      _socket!.emit('join_room', 'admin');
      _socket!.emit('joinRoom', 'admin');
      _socket!.emit('join_admin');
      _socket!.emit('admin_join');
      _socket!.emit('join', {'userId': userId, 'role': 'admin'});
      debugPrint('[NOTIFICATION] Joined Admin socket channels');
    }
  }

  /// Initialize Socket.IO connection
  Future<void> initSocket() async {
    try {
      final user = await StorageService.getUser();
      final token = await StorageService.getToken();
      final userId = (user?['_id'] ?? user?['id'] ?? user?['userId'])?.toString();
      final role = (user?['role'] ?? await StorageService.getRole() ?? '').toString().trim().toLowerCase();
      final bool isAdmin = role == 'admin' || role == 'superadmin' || role == 'administrator';

      if (userId == null || userId.isEmpty) return;

      _currentUserId = userId;

      if (_socket != null) {
        if (!_socket!.connected) {
          _socket!.connect();
        } else {
          _joinRooms(userId, isAdmin);
          _onlineUsersController.add(Set<String>.from(_onlineUserIds));
        }
        return;
      }

      // Extract socket host URL (remove /api prefix)
      String socketUrl = ApiConstants.baseUrl;
      if (socketUrl.endsWith('/api')) {
        socketUrl = socketUrl.substring(0, socketUrl.length - 4);
      }

      final Map<String, dynamic> authData = {
        'token': token ?? '',
        'userId': userId,
        'role': role,
      };

      final Map<String, dynamic> extraHeaders = {};
      if (token != null && token.isNotEmpty) {
        extraHeaders['Authorization'] = 'Bearer $token';
      }

      _socket = io.io(
        socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setAuth(authData)
            .setQuery(authData)
            .setExtraHeaders(extraHeaders)
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(15)
            .setReconnectionDelay(2000)
            .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        debugPrint('⚡ Socket connected to $socketUrl');
        _joinRooms(userId, isAdmin);
      });

      _socket!.onReconnect((_) {
        _isConnected = true;
        debugPrint('⚡ Socket reconnected to $socketUrl');
        _joinRooms(userId, isAdmin);
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
      // Listen to all backend event variations
      final attendanceEvents = [
        'attendance_marked',
        'attendanceMarked',
        'attendance:marked',
        'attendance_mark',
        'attendance_created',
        'attendanceCreated',
        'new_attendance',
        'newAttendance',
        'attendance_checkin',
        'attendance_checkout',
        'attendance_session_marked',
        'admin_attendance_notification',
        'admin_attendance_marked',
        'attendance',
      ];

      for (final eventName in attendanceEvents) {
        _socket!.on(eventName, (data) {
          debugPrint('⚡ [NOTIFICATION] Received $eventName from socket: $data');
          if (data is Map) {
            final map = Map<String, dynamic>.from(data);
            _handleAttendanceMarkedEvent(map);
          }
        });
      }

      // 7. Receive live Attendance Updated broadcast
      final updateEvents = [
        'attendance_updated',
        'attendanceUpdated',
        'attendance:updated',
      ];
      for (final eventName in updateEvents) {
        _socket!.on(eventName, (data) {
          debugPrint('⚡ Received $eventName from socket: $data');
          if (data is Map) {
            final map = Map<String, dynamic>.from(data);
            _attendanceMarkedController.add(map);
          }
        });
      }

      // 8. Receive new notification events
      final generalNotifEvents = [
        'newNotification',
        'receive_notification',
        'notification',
        'admin_notification',
      ];

      for (final eventName in generalNotifEvents) {
        _socket!.on(eventName, (data) {
          debugPrint('⚡ Received $eventName from socket: $data');
          if (data is Map) {
            final map = Map<String, dynamic>.from(data);
            final notif = map['notification'] ?? map['data'] ?? map;
            if (notif is Map) {
              final parsed = Map<String, dynamic>.from(notif);
              final type = (parsed['type'] ?? parsed['notificationType'] ?? parsed['category'] ?? '').toString().toLowerCase();
              if (type.contains('attendance') || type.contains('checkin') || type.contains('checkout')) {
                _handleAttendanceMarkedEvent(parsed);
              } else {
                _handleNotificationEvent(parsed);
              }
            }
          }
        });
      }

    } catch (e) {
      debugPrint('Socket init error: $e');
    }
  }

  /// Handle attendance marked event and trigger floating in-app popup notification ONLY for Admin
  void _handleAttendanceMarkedEvent(Map<String, dynamic> rawData) async {
    try {
      debugPrint('[NOTIFICATION] Event received by Admin');

      // Unwrap data payload if nested
      final Map<String, dynamic> data = (rawData['data'] is Map)
          ? Map<String, dynamic>.from(rawData['data'])
          : (rawData['attendance'] is Map)
              ? Map<String, dynamic>.from(rawData['attendance'])
              : rawData;

      // 1. Notify streams so all screens/charts can silently refresh data without refresh
      _attendanceMarkedController.add(data);

      // 2. Strict Role-Based Check using backend user state
      final user = await StorageService.getUser();
      final role = (user?['role'] ?? await StorageService.getRole() ?? '').toString().trim().toLowerCase();
      final bool isAdmin = role == 'admin' || role == 'superadmin' || role == 'administrator';

      // IF logged-in user's role == "admin" -> Show attendance popup notification
      // ELSE IF logged-in user's role == "employee" -> DO NOT show attendance popup notification
      if (!isAdmin) {
        debugPrint('Skipping attendance popup: User role is "$role", not "admin".');
        return;
      }

      // Extract employee details
      final empData = data['employee'] is Map
          ? Map<String, dynamic>.from(data['employee'])
          : (data['user'] is Map
              ? Map<String, dynamic>.from(data['user'])
              : (rawData['employee'] is Map ? Map<String, dynamic>.from(rawData['employee']) : null));

      final String empDisplayId = (empData?['employeeId'] ??
              empData?['empId'] ??
              empData?['id'] ??
              empData?['_id'] ??
              data['employeeId'] ??
              data['empId'] ??
              rawData['employeeId'] ??
              '')
          .toString().trim();

      final String empEmail = (empData?['email'] ??
              data['employeeEmail'] ??
              data['email'] ??
              rawData['employeeEmail'] ??
              rawData['email'] ??
              '')
          .toString().trim();

      final String empName = (empData?['name'] ??
              empData?['fullName'] ??
              empData?['userName'] ??
              data['employeeName'] ??
              data['name'] ??
              data['userName'] ??
              rawData['employeeName'] ??
              rawData['name'] ??
              (empEmail.isNotEmpty ? empEmail.split('@').first : 'Employee'))
          .toString().trim();

      final String rawAction = (data['action'] ??
              data['attendanceType'] ??
              data['type'] ??
              data['status'] ??
              rawData['action'] ??
              rawData['attendanceType'] ??
              rawData['type'] ??
              'Check-In')
          .toString();

      final String rawMsg = (data['message'] ?? rawData['message'] ?? '').toString();
      final String rawTitle = (data['title'] ?? rawData['title'] ?? '').toString();

      final bool isCheckOut = rawAction.toLowerCase().contains('out') ||
          rawMsg.toLowerCase().contains('out') ||
          rawTitle.toLowerCase().contains('out');

      final String attendanceType = isCheckOut ? 'Check Out' : 'Check In';
      final String method = (data['method'] ??
              data['verificationMethod'] ??
              data['attendanceMethod'] ??
              rawData['method'] ??
              rawData['verificationMethod'] ??
              rawData['attendanceMethod'] ??
              '')
          .toString();

      // Extract Date & Time
      final rawDate = data['date'] ?? data['attendanceDate'] ?? data['createdAt'] ?? rawData['date'] ?? rawData['createdAt'];
      final rawTime = data['time'] ?? data['attendanceTime'] ?? data['checkInTime'] ?? data['checkOutTime'] ?? data['exactTime'] ?? rawData['time'];

      DateTime eventDateTime = DateTime.now();
      if (rawDate != null) {
        try {
          String s = rawDate.toString().trim();
          if (s.contains('T') && !s.endsWith('Z') && !s.contains('+')) s += 'Z';
          eventDateTime = DateTime.parse(s).toLocal();
        } catch (_) {}
      }

      String dateStr = DateFormat('dd MMM yyyy').format(eventDateTime);
      String timeStr;
      if (rawTime != null && rawTime.toString().isNotEmpty) {
        final tStr = rawTime.toString().trim();
        if (tStr.contains(':')) {
          timeStr = tStr;
        } else {
          timeStr = DateFormat('h:mm a').format(eventDateTime);
        }
      } else {
        timeStr = DateFormat('h:mm a').format(eventDateTime);
      }

      final String attendanceId = (data['attendanceId'] ??
              data['id'] ??
              data['_id'] ??
              data['recordId'] ??
              rawData['attendanceId'] ??
              rawData['id'] ??
              rawData['_id'] ??
              'att_${DateTime.now().millisecondsSinceEpoch}')
          .toString();

      // Deduplicate rapid duplicate events (e.g. from broadcast + direct notification)
      final String idOrEmail = empDisplayId.isNotEmpty ? empDisplayId : (empEmail.isNotEmpty ? empEmail : empName);
      final String dedupKey = 'att_${idOrEmail}_${isCheckOut ? 'out' : 'in'}_$dateStr';

      if (RealtimeNotificationService.isDuplicateRecentlyShown(dedupKey) ||
          RealtimeNotificationService.isDuplicateRecentlyShown(attendanceId)) {
        debugPrint('[NOTIFICATION] Duplicate attendance notification suppressed: $dedupKey');
        return;
      }
      RealtimeNotificationService.markAsShown(dedupKey);
      RealtimeNotificationService.markAsShown(attendanceId);

      final String idStr = empDisplayId.isNotEmpty
          ? ' ($empDisplayId)'
          : (empEmail.isNotEmpty ? ' ($empEmail)' : '');
      final String methodStr = method.isNotEmpty ? ' via $method' : '';

      final String title = '$attendanceType: $empName';
      final String message = rawMsg.isNotEmpty
          ? rawMsg
          : '$empName$idStr marked $attendanceType at $timeStr on $dateStr$methodStr.';

      final category = isCheckOut
          ? NotificationCategory.attendanceCheckOut
          : NotificationCategory.attendanceCheckIn;

      final item = RealtimeNotificationItem(
        id: attendanceId,
        title: title,
        message: message,
        type: isCheckOut ? 'attendance_checkout' : 'attendance_checkin',
        category: category,
        createdAt: eventDateTime,
      );

      // Show top-floating popup dialog ONLY to Admin users
      RealtimeNotificationService.showTopNotificationPopup(null, item);

      // Trigger native system vibration & sound ONLY to Admin users
      RealtimeNotificationService.showNativeSystemNotification(item);

      debugPrint('[NOTIFICATION] Popup displayed for $empName ($attendanceType)');
    } catch (e) {
      debugPrint('Error handling attendance socket event: $e');
    }
  }

  /// Handle general/system notification event and trigger popup
  void _handleNotificationEvent(Map<String, dynamic> data) async {
    try {
      final user = await StorageService.getUser();
      final role = (user?['role'] ?? await StorageService.getRole() ?? '').toString().trim().toLowerCase();
      final bool isAdmin = role == 'admin' || role == 'superadmin' || role == 'administrator';

      final type = (data['type'] ?? data['notificationType'] ?? 'general').toString().toLowerCase();
      final receiverRole = (data['receiverRole'] ?? '').toString().toLowerCase();

      final isAttendance = type.contains('attendance') || type == 'checkout' || type == 'checkin';

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
      _currentUserId = null;
      _onlineUserIds.clear();
      debugPrint('⚡ Socket disconnected and reset.');
    }
  }
}


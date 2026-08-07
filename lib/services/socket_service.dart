import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/constants/api_constants.dart';
import '../core/utils/storage_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  String? _currentUserId;

  // Stream Controllers
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _onlineUsersController = StreamController<Set<String>>.broadcast();
  final _userStatusController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Set<String>> get onlineUsersStream => _onlineUsersController.stream;
  Stream<Map<String, dynamic>> get userStatusStream => _userStatusController.stream;

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

      if (_socket != null && _socket!.connected) {
        _socket!.emit('join', userId);
        return;
      }

      // Extract socket host URL (remove /api prefix)
      String socketUrl = ApiConstants.baseUrl;
      if (socketUrl.endsWith('/api')) {
        socketUrl = socketUrl.substring(0, socketUrl.length - 4);
      }

      _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        print('⚡ Socket connected to $socketUrl');
        if (_currentUserId != null) {
          _socket!.emit('join', _currentUserId);
        }
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        print('💤 Socket disconnected');
      });

      // Receive real-time message
      _socket!.on('receive_message', (data) {
        if (data is Map) {
          _messageController.add(Map<String, dynamic>.from(data));
        }
      });

      // Receive typing indicator
      _socket!.on('typing', (data) {
        if (data is Map) {
          _typingController.add(Map<String, dynamic>.from(data));
        }
      });

      // Receive list of current online users
      _socket!.on('online_users', (data) {
        if (data is List) {
          _onlineUserIds = data.map((e) => e.toString()).toSet();
          _onlineUsersController.add(_onlineUserIds);
        }
      });

      // Receive user status change (online / offline / last seen)
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
            _onlineUsersController.add(_onlineUserIds);
            _userStatusController.add(statusMap);
          }
        }
      });

    } catch (e) {
      print('Socket init error: $e');
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

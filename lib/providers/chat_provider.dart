import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/chat_service.dart';
import '../services/socket_service.dart';
import '../core/utils/storage_service.dart';

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});

class ChatState {
  final bool isLoading;
  final List<dynamic> conversations;
  final List<dynamic> contacts;
  final Map<String, List<dynamic>> messagesMap; // userId -> list of messages
  final Set<String> onlineUserIds;
  final Map<String, bool> typingMap; // userId -> isTyping
  final int totalUnread;
  final String? error;

  const ChatState({
    this.isLoading = false,
    this.conversations = const [],
    this.contacts = const [],
    this.messagesMap = const {},
    this.onlineUserIds = const {},
    this.typingMap = const {},
    this.totalUnread = 0,
    this.error,
  });

  ChatState copyWith({
    bool? isLoading,
    List<dynamic>? conversations,
    List<dynamic>? contacts,
    Map<String, List<dynamic>>? messagesMap,
    Set<String>? onlineUserIds,
    Map<String, bool>? typingMap,
    int? totalUnread,
    String? error,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      conversations: conversations ?? this.conversations,
      contacts: contacts ?? this.contacts,
      messagesMap: messagesMap ?? this.messagesMap,
      onlineUserIds: onlineUserIds ?? this.onlineUserIds,
      typingMap: typingMap ?? this.typingMap,
      totalUnread: totalUnread ?? this.totalUnread,
      error: error ?? this.error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  StreamSubscription? _msgSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _onlineSub;

  ChatNotifier() : super(const ChatState()) {
    init();
  }

  Future<void> init() async {
    await loadConversations();
    await loadContacts();
    await loadUnreadCount();
    _initSocketListeners();
  }

  String? _extractId(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return raw;
    if (raw is Map) {
      return (raw['_id'] ?? raw['id'] ?? raw['userId'])?.toString();
    }
    return raw.toString();
  }

  void _initSocketListeners() async {
    final socketService = SocketService();
    await socketService.initSocket();

    _msgSub?.cancel();
    _msgSub = socketService.messageStream.listen((msg) {
      _handleIncomingSocketMessage(msg);
    });

    _typingSub?.cancel();
    _typingSub = socketService.typingStream.listen((data) {
      final uid = _extractId(data['userId']);
      final isTyping = data['isTyping'] == true;
      if (uid != null) {
        final updatedTyping = Map<String, bool>.from(state.typingMap);
        updatedTyping[uid] = isTyping;
        state = state.copyWith(typingMap: updatedTyping);
      }
    });

    _onlineSub?.cancel();
    _onlineSub = socketService.onlineUsersStream.listen((onlineIds) {
      state = state.copyWith(onlineUserIds: onlineIds);
    });
  }

  void _handleIncomingSocketMessage(Map<String, dynamic> msg) async {
    final senderId = _extractId(msg['senderId'] ?? msg['sender']);
    final receiverId = _extractId(msg['receiverId'] ?? msg['receiver']);
    final user = await StorageService.getUser();
    final currentUserId = _extractId(user);

    if (senderId == null || senderId.isEmpty) return;
    if (currentUserId == null || currentUserId.isEmpty) return;

    // Target user is the chat partner (the other person in the 1-on-1 conversation)
    final targetUserId = (senderId == currentUserId) ? receiverId : senderId;
    if (targetUserId == null || targetUserId.isEmpty) return;

    // Update active chat message list if cached
    final currentMap = Map<String, List<dynamic>>.from(state.messagesMap);
    final userMsgs = List<dynamic>.from(currentMap[targetUserId] ?? []);
    
    // Deduplication using id, _id, or tempId
    final newId = _extractId(msg['id'] ?? msg['_id']) ?? msg['tempId']?.toString();
    final tempId = msg['tempId']?.toString();

    final existsIndex = userMsgs.indexWhere((m) {
      final mId = _extractId(m['id'] ?? m['_id']) ?? m['tempId']?.toString();
      final mTempId = m['tempId']?.toString();
      
      if (newId != null && mId != null && newId == mId) return true;
      if (tempId != null && mTempId != null && tempId == mTempId) return true;
      return false;
    });

    if (existsIndex >= 0) {
      userMsgs[existsIndex] = msg;
    } else {
      userMsgs.add(msg);
    }

    currentMap[targetUserId] = userMsgs;

    // Real-time conversation list update
    final conversations = List<dynamic>.from(state.conversations);
    final convIndex = conversations.indexWhere((c) {
      final cUserId = _extractId(c['userId'] ?? c['user']?['_id'] ?? c['user']?['id']);
      return cUserId == targetUserId;
    });

    final lastMsgObj = {
      'message': msg['message'] ?? '',
      'timestamp': msg['timestamp'] ?? msg['createdAt'] ?? DateTime.now().toUtc().toIso8601String(),
      'senderId': senderId,
    };

    if (convIndex >= 0) {
      final existingConv = Map<String, dynamic>.from(conversations[convIndex]);
      existingConv['lastMessage'] = lastMsgObj;
      if (senderId != currentUserId) {
        existingConv['unreadCount'] = (existingConv['unreadCount'] ?? 0) + 1;
      }
      conversations[convIndex] = existingConv;
    }

    state = state.copyWith(
      messagesMap: currentMap,
      conversations: conversations,
    );

    // Refresh unread count and conversations from server for sync
    loadUnreadCount();
  }

  /// Load conversations from API
  Future<void> loadConversations() async {
    try {
      final data = await ChatService.getConversations();
      final rawList = data['conversations'] ?? data['data'] ?? [];
      final list = rawList is List ? List<dynamic>.from(rawList) : <dynamic>[];
      state = state.copyWith(conversations: list);
    } catch (_) {}
  }

  /// Load system contacts from API
  Future<void> loadContacts() async {
    try {
      final data = await ChatService.getUsers();
      final rawList = data['users'] ?? data['data'] ?? [];
      final list = rawList is List ? List<dynamic>.from(rawList) : <dynamic>[];
      state = state.copyWith(contacts: list);
    } catch (_) {}
  }

  /// Load total unread count
  Future<void> loadUnreadCount() async {
    try {
      final data = await ChatService.getUnreadCount();
      final count = (data['totalUnread'] ?? data['count'] ?? 0) as int;
      state = state.copyWith(totalUnread: count);
    } catch (_) {}
  }

  /// Load chat history with specific user
  Future<void> loadMessages(String userId) async {
    try {
      final data = await ChatService.getMessages(userId);
      final rawList = data['messages'] ?? data['data'] ?? [];
      final list = rawList is List ? List<dynamic>.from(rawList) : <dynamic>[];
      
      final currentMap = Map<String, List<dynamic>>.from(state.messagesMap);
      currentMap[userId] = list;
      state = state.copyWith(messagesMap: currentMap);

      // Mark messages as read on backend
      await ChatService.markAsRead(userId);
      await loadUnreadCount();
      await loadConversations();
    } catch (_) {}
  }

  /// Send message
  Future<bool> sendMessage({
    required String receiverId,
    required String text,
    String messageType = 'text',
    String? fileUrl,
    String? fileName,
    String? fileType,
  }) async {
    try {
      final user = await StorageService.getUser();
      final senderId = _extractId(user) ?? '';
      final senderName = (user?['name'] ?? 'Me').toString();

      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final utcNowIso = DateTime.now().toUtc().toIso8601String();
      final localMsg = {
        'id': tempId,
        '_id': tempId,
        'tempId': tempId,
        'senderId': senderId,
        'senderName': senderName,
        'receiverId': receiverId,
        'message': text,
        'messageType': messageType,
        'fileUrl': fileUrl ?? '',
        'fileName': fileName ?? '',
        'fileType': fileType ?? '',
        'timestamp': utcNowIso,
        'createdAt': utcNowIso,
        'read': false,
        'delivered': false,
      };

      // Optimistically append to chat UI
      final currentMap = Map<String, List<dynamic>>.from(state.messagesMap);
      final userMsgs = List<dynamic>.from(currentMap[receiverId] ?? []);
      userMsgs.add(localMsg);
      currentMap[receiverId] = userMsgs;

      // Optimistically update conversation entry
      final conversations = List<dynamic>.from(state.conversations);
      final convIndex = conversations.indexWhere((c) {
        final cUserId = _extractId(c['userId'] ?? c['user']?['_id'] ?? c['user']?['id']);
        return cUserId == receiverId;
      });
      if (convIndex >= 0) {
        final existingConv = Map<String, dynamic>.from(conversations[convIndex]);
        existingConv['lastMessage'] = {
          'message': text,
          'timestamp': utcNowIso,
          'createdAt': utcNowIso,
          'senderId': senderId,
        };
        conversations[convIndex] = existingConv;
      }
          'senderId': senderId,
        };
        conversations[convIndex] = existingConv;
      }

      state = state.copyWith(
        messagesMap: currentMap,
        conversations: conversations,
      );

      // Emit socket event for instant socket delivery
      SocketService().sendMessage(localMsg);

      // Persist to backend database via API
      final res = await ChatService.sendMessage(
        receiverId: receiverId,
        message: text,
        messageType: messageType,
        fileUrl: fileUrl,
        fileName: fileName,
        fileType: fileType,
      );

      if (res['success'] == true) {
        if (res['data'] != null) {
          final serverMsg = res['data'];
          final updatedMap = Map<String, List<dynamic>>.from(state.messagesMap);
          final msgs = List<dynamic>.from(updatedMap[receiverId] ?? []);
          final idx = msgs.indexWhere((m) => m['tempId'] == tempId || m['id'] == tempId || m['_id'] == tempId);
          if (idx >= 0) {
            msgs[idx] = serverMsg;
            updatedMap[receiverId] = msgs;
            state = state.copyWith(messagesMap: updatedMap);
          }
        }
        await loadConversations();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Send typing indicator
  void sendTypingStatus(String receiverId, bool isTyping) {
    SocketService().sendTypingStatus(receiverId, isTyping);
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _typingSub?.cancel();
    _onlineSub?.cancel();
    super.dispose();
  }
}

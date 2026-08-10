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

  void _initSocketListeners() async {
    final socketService = SocketService();
    await socketService.initSocket();

    _msgSub?.cancel();
    _msgSub = socketService.messageStream.listen((msg) {
      _handleIncomingSocketMessage(msg);
    });

    _typingSub?.cancel();
    _typingSub = socketService.typingStream.listen((data) {
      final uid = data['userId']?.toString();
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
    final senderId = (msg['senderId'] ?? msg['sender'])?.toString();
    final currentUserId = (await StorageService.getUser())?['_id']?.toString();

    if (senderId == null || senderId.isEmpty) return;

    final targetUserId = (senderId == currentUserId) ? msg['receiverId']?.toString() : senderId;
    if (targetUserId == null) return;

    // Update active chat message list if cached
    final currentMap = Map<String, List<dynamic>>.from(state.messagesMap);
    final userMsgs = List<dynamic>.from(currentMap[targetUserId] ?? []);
    
    // Deduplicate
    final newId = (msg['id'] ?? msg['_id'] ?? msg['tempId'])?.toString();
    final exists = userMsgs.any((m) => (m['id'] ?? m['_id'])?.toString() == newId);
    if (!exists) {
      userMsgs.add(msg);
      currentMap[targetUserId] = userMsgs;
      state = state.copyWith(messagesMap: currentMap);
    }

    // Refresh conversations list
    await loadConversations();
    await loadUnreadCount();
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
      final senderId = (user?['_id'] ?? user?['id'])?.toString() ?? '';
      final senderName = (user?['name'] ?? 'Me').toString();

      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final localMsg = {
        'id': tempId,
        '_id': tempId,
        'senderId': senderId,
        'senderName': senderName,
        'receiverId': receiverId,
        'message': text,
        'messageType': messageType,
        'fileUrl': fileUrl ?? '',
        'fileName': fileName ?? '',
        'fileType': fileType ?? '',
        'timestamp': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'read': false,
        'delivered': false,
      };

      // Optimistically append to chat UI
      final currentMap = Map<String, List<dynamic>>.from(state.messagesMap);
      final userMsgs = List<dynamic>.from(currentMap[receiverId] ?? []);
      userMsgs.add(localMsg);
      currentMap[receiverId] = userMsgs;
      state = state.copyWith(messagesMap: currentMap);

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
        await loadMessages(receiverId);
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

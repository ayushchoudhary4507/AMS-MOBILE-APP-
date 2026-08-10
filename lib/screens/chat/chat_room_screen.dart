import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/storage_service.dart';
import '../../providers/chat_provider.dart';
import '../../services/chat_service.dart';
import '../../widgets/common/app_avatar.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String targetUserId;
  final Map<String, dynamic>? initialUserData;

  const ChatRoomScreen({
    super.key,
    required this.targetUserId,
    this.initialUserData,
  });

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).loadMessages(widget.targetUserId);
    });
  }

  void _loadCurrentUserId() async {
    final user = await StorageService.getUser();
    final uid = (user?['_id'] ?? user?['id'] ?? user?['userId'])?.toString() ?? '';
    if (mounted) {
      setState(() => _currentUserId = uid);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    ref.read(chatProvider.notifier).sendTypingStatus(widget.targetUserId, false);

    await ref.read(chatProvider.notifier).sendMessage(
          receiverId: widget.targetUserId,
          text: text,
          messageType: 'text',
        );

    _scrollToBottom();
  }

  void _pickAndUploadImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );
      if (pickedFile == null) return;

      setState(() => _isUploading = true);

      final file = File(pickedFile.path);
      final res = await ChatService.uploadFile(file);

      setState(() => _isUploading = false);

      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        final fileUrl = data['fileUrl']?.toString() ?? '';
        final fileName = data['fileName']?.toString() ?? 'Image';

        await ref.read(chatProvider.notifier).sendMessage(
              receiverId: widget.targetUserId,
              text: '📷 Photo',
              messageType: 'image',
              fileUrl: fileUrl,
              fileName: fileName,
              fileType: 'image/jpeg',
            );
        _scrollToBottom();
      }
    } catch (_) {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final messages = chatState.messagesMap[widget.targetUserId] ?? [];
    final isOnline = chatState.onlineUserIds.contains(widget.targetUserId);
    final isTyping = chatState.typingMap[widget.targetUserId] == true;

    final targetName = (widget.initialUserData?['name'] ?? 'User').toString();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                AppAvatar(avatarOrUser: targetName, fallbackText: targetName.isNotEmpty ? targetName[0] : 'U', radius: 20),
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: context.cardBg, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    targetName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.txtPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isTyping
                        ? 'typing...'
                        : (isOnline ? 'Online' : 'Offline'),
                    style: TextStyle(
                      fontSize: 12,
                      color: isTyping
                          ? AppColors.primary
                          : (isOnline ? const Color(0xFF10B981) : context.txtSecondary),
                      fontWeight: isTyping ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isUploading)
            const LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),

          // Messages List
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyChatRoom(targetName)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final senderId = (msg['senderId'] ?? msg['sender'])?.toString();
                      final isMe = senderId == _currentUserId;
                      final text = (msg['message'] ?? '').toString();
                      final type = (msg['messageType'] ?? 'text').toString();
                      final fileUrl = (msg['fileUrl'] ?? '').toString();
                      final isRead = msg['read'] == true;
                      final isDelivered = msg['delivered'] == true;

                      final rawTime = msg['createdAt'] ?? msg['timestamp'] ?? msg['created_at'] ?? msg['date'] ?? msg['time'];
                      DateTime? time;
                      if (rawTime != null) {
                        if (rawTime is DateTime) {
                          time = rawTime.toLocal();
                        } else {
                          time = DateTime.tryParse(rawTime.toString())?.toLocal();
                        }
                      }
                      time ??= DateTime.now();
                      final timeStr = DateFormat('hh:mm a').format(time);

                      return _buildMessageBubble(
                        context: context,
                        isMe: isMe,
                        text: text,
                        type: type,
                        fileUrl: fileUrl,
                        timeStr: timeStr,
                        isRead: isRead,
                        isDelivered: isDelivered,
                      );
                    },
                  ),
          ),

          // Input Section
          _buildMessageInputSection(),
        ],
      ),
    );
  }

  Widget _buildEmptyChatRoom(String targetName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 54, color: AppColors.primary),
            const SizedBox(height: 14),
            Text(
              'Say Hello to $targetName 👋',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.txtPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'End-to-end connected real-time chat.',
              style: TextStyle(color: context.txtSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required BuildContext context,
    required bool isMe,
    required String text,
    required String type,
    required String fileUrl,
    required String timeStr,
    required bool isRead,
    required bool isDelivered,
  }) {
    final bubbleBg = isMe
        ? AppColors.primary
        : context.cardBg;
    final textColor = isMe ? Colors.white : context.txtPrimary;

    String absoluteFileUrl = fileUrl;
    if (fileUrl.isNotEmpty && !fileUrl.startsWith('http')) {
      String base = ApiConstants.baseUrl;
      if (base.endsWith('/api')) base = base.substring(0, base.length - 4);
      absoluteFileUrl = '$base$fileUrl';
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image Attachment
            if (type == 'image' && absoluteFileUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: absoluteFileUrl,
                  placeholder: (context, url) => Container(
                    height: 150,
                    color: Colors.black12,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image_rounded, size: 48),
                ),
              ),
              const SizedBox(height: 6),
            ],

            // Text message
            if (text.isNotEmpty && type != 'image')
              Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  height: 1.3,
                ),
              ),

            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : context.txtSecondary,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all_rounded : (isDelivered ? Icons.done_all_rounded : Icons.done_rounded),
                    size: 14,
                    color: isRead ? const Color(0xFF60A5FA) : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInputSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(top: BorderSide(color: context.borderCol.withValues(alpha: 0.5))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Attachment Button
            IconButton(
              icon: const Icon(Icons.attach_file_rounded, color: AppColors.primary),
              onPressed: _pickAndUploadImage,
            ),

            // Text Field
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.borderCol.withValues(alpha: 0.5)),
                ),
                child: TextField(
                  controller: _messageController,
                  onChanged: (val) {
                    ref.read(chatProvider.notifier).sendTypingStatus(widget.targetUserId, val.isNotEmpty);
                  },
                  onSubmitted: (_) => _handleSendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Send Button
            GestureDetector(
              onTap: _handleSendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

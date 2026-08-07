import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/common/app_avatar.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).loadConversations();
      ref.read(chatProvider.notifier).loadContacts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final conversations = chatState.conversations;
    final onlineUserIds = chatState.onlineUserIds;

    final filteredConversations = conversations.where((conv) {
      final userName = (conv['userName'] ?? conv['user']?['name'] ?? '').toString().toLowerCase();
      final userEmail = (conv['userEmail'] ?? conv['user']?['email'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return userName.contains(q) || userEmail.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(chatProvider.notifier).loadConversations();
              ref.read(chatProvider.notifier).loadContacts();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderCol.withValues(alpha: 0.5)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search chats or employees...',
                  prefixIcon: Icon(Icons.search_rounded, color: context.txtSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // Conversation List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(chatProvider.notifier).loadConversations();
                await ref.read(chatProvider.notifier).loadContacts();
              },
              child: filteredConversations.isEmpty
                  ? _buildEmptyState(context, chatState.contacts)
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filteredConversations.length,
                      separatorBuilder: (_, __) => Divider(
                        color: context.borderCol.withValues(alpha: 0.3),
                        height: 1,
                        indent: 76,
                      ),
                      itemBuilder: (context, index) {
                        final conv = filteredConversations[index];
                        final userId = (conv['userId'] ?? conv['user']?['_id'] ?? conv['user']?['id'])?.toString() ?? '';
                        final userName = (conv['userName'] ?? conv['user']?['name'] ?? 'User').toString();
                        final userEmail = (conv['userEmail'] ?? conv['user']?['email'] ?? '').toString();
                        final lastMsgObj = conv['lastMessage'];
                        final lastMsg = (lastMsgObj is Map ? lastMsgObj['message'] : lastMsgObj)?.toString() ?? '';
                        final unreadCount = (conv['unreadCount'] ?? 0) as int;
                        final isOnline = onlineUserIds.contains(userId);

                        DateTime? time;
                        if (lastMsgObj is Map && lastMsgObj['timestamp'] != null) {
                          time = DateTime.tryParse(lastMsgObj['timestamp'].toString());
                        }

                        final timeStr = time != null
                            ? DateFormat(DateTime.now().day == time.day ? 'hh:mm a' : 'MMM d').format(time)
                            : '';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          onTap: () {
                            context.push('/chat/$userId', extra: {
                              'name': userName,
                              'email': userEmail,
                            });
                          },
                          leading: Stack(
                            children: [
                              AppAvatar(
                                avatarOrUser: userName,
                                fallbackText: userName.isNotEmpty ? userName[0] : 'U',
                                radius: 24,
                              ),
                              if (isOnline)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: context.cardBg, width: 2.5),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  userName,
                                  style: TextStyle(
                                    fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 16,
                                    color: context.txtPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (timeStr.isNotEmpty)
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: unreadCount > 0 ? AppColors.primary : context.txtSecondary,
                                    fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lastMsg.isEmpty ? 'Tap to start chat' : lastMsg,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: unreadCount > 0 ? context.txtPrimary : context.txtSecondary,
                                    fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (unreadCount > 0)
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showStartChatModal(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, List<dynamic> contacts) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.forum_outlined, size: 64, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              Text(
                'No Messages Yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.txtPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start a new conversation with your colleagues or admin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.txtSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _showStartChatModal(context),
                icon: const Icon(Icons.person_add_rounded, color: Colors.white),
                label: const Text('Start New Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStartChatModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return Consumer(
          builder: (context, ref, child) {
            final chatState = ref.watch(chatProvider);
            final contacts = chatState.contacts;
            final onlineUserIds = chatState.onlineUserIds;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select Contact',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.txtPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: contacts.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: contacts.length,
                            itemBuilder: (ctx, i) {
                              final contact = contacts[i];
                              final id = (contact['id'] ?? contact['_id'])?.toString() ?? '';
                              final name = (contact['name'] ?? 'User').toString();
                              final email = (contact['email'] ?? '').toString();
                              final role = (contact['role'] ?? 'employee').toString();
                              final isOnline = onlineUserIds.contains(id);

                              return ListTile(
                                leading: Stack(
                                  children: [
                                    AppAvatar(avatarOrUser: name, fallbackText: name.isNotEmpty ? name[0] : 'U', radius: 22),
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
                                title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: context.txtPrimary)),
                                subtitle: Text(
                                  '${role.toUpperCase()} • $email',
                                  style: TextStyle(fontSize: 12, color: context.txtSecondary),
                                ),
                                onTap: () {
                                  Navigator.pop(modalCtx);
                                  context.push('/chat/$id', extra: {
                                    'name': name,
                                    'email': email,
                                    'role': role,
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/employee_provider.dart';
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
      ref.read(employeeProvider.notifier).loadEmployees();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _extractId(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw;
    if (raw is Map) {
      return (raw['_id'] ?? raw['id'] ?? raw['userId'])?.toString() ?? '';
    }
    return raw.toString();
  }

  dynamic _resolveUserAvatar(
    dynamic userOrConv,
    List<dynamic> contacts,
    List<dynamic> employees,
  ) {
    final direct = extractAvatarUrl(userOrConv);
    if (direct != null && direct.isNotEmpty) return direct;

    String? uid;
    String? uEmail;
    String? uName;

    if (userOrConv is Map) {
      uid = (userOrConv['_id'] ??
              userOrConv['id'] ??
              userOrConv['userId'] ??
              userOrConv['user']?['_id'] ??
              userOrConv['user']?['id'])
          ?.toString();
      uEmail = (userOrConv['email'] ??
              userOrConv['userEmail'] ??
              userOrConv['user']?['email'])
          ?.toString();
      uName = (userOrConv['name'] ??
              userOrConv['userName'] ??
              userOrConv['user']?['name'])
          ?.toString();
    } else if (userOrConv is String) {
      uid = userOrConv;
    }

    // 1. Check in contacts
    for (final c in contacts) {
      if (c is Map) {
        final cId = (c['_id'] ?? c['id'])?.toString();
        final cEmail = c['email']?.toString();
        final cName = c['name']?.toString();
        if ((uid != null && uid.isNotEmpty && uid == cId) ||
            (uEmail != null &&
                uEmail.isNotEmpty &&
                uEmail.toLowerCase() == cEmail?.toLowerCase()) ||
            (uName != null &&
                uName.isNotEmpty &&
                uName.toLowerCase() == cName?.toLowerCase())) {
          final av = extractAvatarUrl(c);
          if (av != null && av.isNotEmpty) return av;
        }
      }
    }

    // 2. Check in employees
    for (final e in employees) {
      if (e is Map) {
        final eId = (e['_id'] ?? e['id'])?.toString();
        final eEmail = e['email']?.toString();
        final eName = e['name']?.toString();
        if ((uid != null && uid.isNotEmpty && uid == eId) ||
            (uEmail != null &&
                uEmail.isNotEmpty &&
                uEmail.toLowerCase() == eEmail?.toLowerCase()) ||
            (uName != null &&
                uName.isNotEmpty &&
                uName.toLowerCase() == eName?.toLowerCase())) {
          final av = extractAvatarUrl(e);
          if (av != null && av.isNotEmpty) return av;
        }
      }
    }

    // 3. Check avatarCache
    if (uEmail != null &&
        uEmail.isNotEmpty &&
        StorageService.avatarCache.containsKey(uEmail.toLowerCase())) {
      final cached = StorageService.avatarCache[uEmail.toLowerCase()];
      if (cached != null && cached.isNotEmpty) return cached;
    }
    if (uid != null &&
        uid.isNotEmpty &&
        StorageService.avatarCache.containsKey(uid.toLowerCase())) {
      final cached = StorageService.avatarCache[uid.toLowerCase()];
      if (cached != null && cached.isNotEmpty) return cached;
    }
    if (uName != null &&
        uName.isNotEmpty &&
        StorageService.avatarCache.containsKey(uName.toLowerCase())) {
      final cached = StorageService.avatarCache[uName.toLowerCase()];
      if (cached != null && cached.isNotEmpty) return cached;
    }

    return userOrConv;
  }

  DateTime? _parseToLocal(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toLocal();
    final str = raw.toString().trim();
    if (str.isEmpty) return null;

    try {
      String formattedStr = str;
      if (formattedStr.contains('T') &&
          !formattedStr.endsWith('Z') &&
          !formattedStr.substring(formattedStr.indexOf('T')).contains('+') &&
          !formattedStr.substring(formattedStr.indexOf('T')).contains('-')) {
        formattedStr += 'Z';
      }
      return DateTime.parse(formattedStr).toLocal();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final conversations = chatState.conversations;
    final onlineUserIds = chatState.onlineUserIds;

    final filteredConversations = conversations.where((c) {
      final name = (c['userName'] ?? c['user']?['name'] ?? '').toString().toLowerCase();
      final email = (c['userEmail'] ?? c['user']?['email'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || email.contains(_searchQuery);
    }).toList();

    final employees = ref.watch(employeeProvider).employees;

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
              ref.read(employeeProvider.notifier).loadEmployees();
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
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
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
                await ref.read(employeeProvider.notifier).loadEmployees();
              },
              child: filteredConversations.isEmpty
                  ? _buildEmptyState(context, chatState.contacts)
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filteredConversations.length,
                      separatorBuilder: (_, _) => Divider(
                        color: context.borderCol.withValues(alpha: 0.3),
                        height: 1,
                        indent: 76,
                      ),
                      itemBuilder: (context, index) {
                        final conv = filteredConversations[index];
                        final userId = _extractId(conv['userId'] ?? conv['user'] ?? conv['id'] ?? conv['_id']);
                        final userName = (conv['userName'] ?? conv['user']?['name'] ?? 'User').toString();
                        final userEmail = (conv['userEmail'] ?? conv['user']?['email'] ?? '').toString();
                        final resolvedAvatar = _resolveUserAvatar(conv['user'] ?? conv, chatState.contacts, employees);
                        final lastMsgObj = conv['lastMessage'];
                        final lastMsg = (lastMsgObj is Map ? lastMsgObj['message'] : lastMsgObj)?.toString() ?? '';
                        final unreadCount = (conv['unreadCount'] ?? 0) as int;
                        final isOnline = onlineUserIds.contains(userId);

                        final rawTime = lastMsgObj is Map
                            ? (lastMsgObj['createdAt'] ?? lastMsgObj['timestamp'] ?? lastMsgObj['created_at'] ?? lastMsgObj['date'] ?? lastMsgObj['time'])
                            : null;
                        final time = _parseToLocal(rawTime);
                        final now = DateTime.now();

                        final timeStr = time != null
                            ? DateFormat(now.day == time.day && now.month == time.month && now.year == time.year ? 'hh:mm a' : 'MMM d').format(time)
                            : '';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          onTap: () {
                            context.push('/chat/$userId', extra: {
                              'name': userName,
                              'email': userEmail,
                              'avatar': resolvedAvatar,
                              'user': conv['user'] ?? conv,
                            });
                          },
                          leading: Stack(
                            children: [
                              AppAvatar(
                                avatarOrUser: resolvedAvatar,
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
                              final id = _extractId(contact);
                              final name = (contact['name'] ?? 'User').toString();
                              final email = (contact['email'] ?? '').toString();
                              final role = (contact['role'] ?? 'employee').toString();
                              final isOnline = onlineUserIds.contains(id);

                              final contactAvatar = _resolveUserAvatar(contact, contacts, ref.watch(employeeProvider).employees);

                              return ListTile(
                                leading: Stack(
                                  children: [
                                    AppAvatar(
                                      avatarOrUser: contactAvatar,
                                      fallbackText: name.isNotEmpty ? name[0] : 'U',
                                      radius: 22,
                                    ),
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
                                    'avatar': contactAvatar,
                                    'user': contact,
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

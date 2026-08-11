import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../services/employee_service.dart';
import '../../services/realtime_notification_service.dart';

// Stateful notifications provider that supports mark-as-read
final notifScreenProvider =
    StateNotifierProvider<NotifNotifier, NotifState>((ref) {
  return NotifNotifier();
});

class NotifState {
  final bool isLoading;
  final List<dynamic> notifications;
  final String? error;

  const NotifState({
    this.isLoading = false,
    this.notifications = const [],
    this.error,
  });

  NotifState copyWith({
    bool? isLoading,
    List<dynamic>? notifications,
    String? error,
  }) {
    return NotifState(
      isLoading: isLoading ?? this.isLoading,
      notifications: notifications ?? this.notifications,
      error: error ?? this.error,
    );
  }
}

class NotifNotifier extends StateNotifier<NotifState> {
  Timer? _pollTimer;
  final Set<String> _deletedIds = {};

  NotifNotifier() : super(const NotifState()) {
    load();
    _startPolling();
  }

  bool _isSyncing = false;

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_isSyncing) return;
      _isSyncing = true;
      try {
        await syncFromBackend();
      } catch (_) {
      } finally {
        _isSyncing = false;
      }
    });
  }

  Future<void> syncFromBackend() async {
    try {
      final data = await NotificationService.getAll();
      final raw = data['notifications'] ??
          data['data'] ??
          data['result'] ??
          data['items'] ??
          [];
      final list = raw is List ? raw : [];

      final existingIds = state.notifications
          .map((n) => (n['_id'] ?? n['id'] ?? n['notificationId'])?.toString())
          .whereType<String>()
          .toSet();

      final newItems = <dynamic>[];
      for (final item in list) {
        final id = (item['_id'] ?? item['id'] ?? item['notificationId'])?.toString();
        if (id != null && id.isNotEmpty && !existingIds.contains(id) && !_deletedIds.contains(id)) {
          newItems.add(item);
        }
      }

      if (newItems.isNotEmpty) {
        state = state.copyWith(notifications: [...newItems, ...state.notifications]);
        final role = (await StorageService.getRole())?.toLowerCase() ?? 'employee';
        final user = await StorageService.getUser();
        final currentUserId = (user?['_id'] ?? user?['id'] ?? user?['userId'])?.toString();

        for (final item in newItems) {
          if (item is Map) {
            final senderId = (item['senderId'] ?? item['sender'])?.toString();
            final receiverId = (item['receiverId'] ?? item['receiver'])?.toString();

            // Do NOT trigger popups/system notifications for self-sent actions/messages
            if (senderId != null && currentUserId != null && senderId == currentUserId) {
              continue;
            }
            // Do NOT trigger popups meant for a different recipient
            if (receiverId != null && currentUserId != null && receiverId != currentUserId) {
              continue;
            }

            final title = item['title']?.toString() ?? 'New Notification';
            final message = item['message']?.toString() ?? item['body']?.toString() ?? '';
            final type = (item['type']?.toString() ?? '').toLowerCase();

            if (role != 'admin') {
              if (type.contains('login') ||
                  type.contains('checkin') ||
                  type.contains('checkout') ||
                  type == 'leave_request') {
                continue;
              }
            }

            final category = type.contains('login')
                ? NotificationCategory.userLogin
                : (type.contains('checkout')
                    ? NotificationCategory.attendanceCheckOut
                    : (type.contains('leave')
                        ? NotificationCategory.leaveRequest
                        : NotificationCategory.attendanceCheckIn));

            final rawTime = item['loginAt'] ?? item['createdAt'] ?? item['timestamp'] ?? item['loginTimestampUtc'];
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

            final notifItem = RealtimeNotificationItem(
              id: (item['_id'] ?? item['id'])?.toString() ?? '',
              title: title,
              message: message,
              type: type,
              category: category,
              createdAt: createdAt,
            );
            RealtimeNotificationService.showTopNotificationPopup(null, notifItem);
            RealtimeNotificationService.showNativeSystemNotification(notifItem);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await NotificationService.getAll();
      final raw = data['notifications'] ??
          data['data'] ??
          data['result'] ??
          data['items'] ??
          [];
      final list = raw is List ? raw : [];
      final filtered = list.where((n) {
        final id = (n['_id'] ?? n['id'] ?? n['notificationId'])?.toString();
        return id == null || !_deletedIds.contains(id);
      }).toList();
      state = state.copyWith(isLoading: false, notifications: filtered);
    } catch (e) {
      state =
          state.copyWith(isLoading: false, notifications: [], error: e.toString());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void prependRealtimeNotification(Map<String, dynamic> item) {
    final id = (item['_id'] ?? item['id'] ?? item['notificationId'])?.toString();
    if (id != null && _deletedIds.contains(id)) return;
    final list = [item, ...state.notifications];
    state = state.copyWith(notifications: list);
  }

  Future<void> markRead(String id) async {
    // Optimistic local update first
    _localMarkRead(id);
    try {
      await NotificationService.markRead(id);
    } catch (_) {}
  }

  Future<void> deleteNotification(String id) async {
    if (id.isNotEmpty) _deletedIds.add(id);
    final updated = state.notifications.where((n) {
      final nId = (n['_id'] ?? n['id'] ?? n['notificationId'])?.toString();
      return nId != id && (nId == null || !_deletedIds.contains(nId));
    }).toList();
    state = state.copyWith(notifications: updated);

    try {
      if (id.isNotEmpty) {
        await NotificationService.delete(id);
      }
    } catch (_) {}
  }

  void _localMarkRead(String id) {
    final updated = state.notifications.map((n) {
      final nId = n['_id']?.toString() ?? n['id']?.toString();
      if (nId == id) {
        final copy = n is Map ? Map<String, dynamic>.from(n) : <String, dynamic>{};
        copy['read'] = true;
        return copy;
      }
      return n;
    }).toList();
    state = state.copyWith(notifications: updated);
  }

  Future<void> markAllRead() async {
    // Optimistic update
    final updated = state.notifications.map((n) {
      if (n is Map) {
        final copy = Map<String, dynamic>.from(n);
        copy['read'] = true;
        return copy;
      }
      return n;
    }).toList();
    state = state.copyWith(notifications: updated);
    try {
      await NotificationService.markAllRead();
    } catch (_) {}
  }
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final auth = ref.read(authProvider);
      StorageService.saveLastRoute(
          auth.isAdmin ? '/admin/notifications' : '/employee/notifications');
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifState = ref.watch(notifScreenProvider);
    final auth = ref.watch(authProvider);

    final unreadCount = notifState.notifications
        .where((n) => (n['read'] ?? n['isRead'] ?? false) == false)
        .length;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: context.mainBgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, ref, unreadCount, auth),
              Expanded(
                child: notifState.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      )
                    : notifState.notifications.isEmpty
                        ? _buildEmptyState(context, ref)
                        : RefreshIndicator(
                            onRefresh: () =>
                                ref.read(notifScreenProvider.notifier).load(),
                            color: AppColors.primary,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: notifState.notifications.length,
                              itemBuilder: (ctx, i) => _buildNotifCard(
                                context,
                                ref,
                                notifState.notifications[i],
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, WidgetRef ref, int unreadCount, AuthState auth) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 10),
      decoration: BoxDecoration(
        color: context.cardBg.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(
              color: context.borderCol.withValues(alpha: 0.5), width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: context.txtPrimary, size: 18),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                auth.isAdmin
                    ? context.go('/admin/dashboard')
                    : context.go('/employee/dashboard');
              }
            },
          ),
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.txtPrimary,
                      letterSpacing: -0.4,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$unreadCount new',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all_rounded,
                  size: 20, color: AppColors.primary),
              tooltip: 'Mark all read',
              onPressed: () =>
                  ref.read(notifScreenProvider.notifier).markAllRead(),
            ),
          IconButton(
            icon:
                Icon(Icons.refresh_rounded, color: context.txtMuted, size: 20),
            tooltip: 'Refresh',
            onPressed: () => ref.read(notifScreenProvider.notifier).load(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 44,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Notifications',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.txtPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You're all caught up!\nNew notifications will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(color: context.txtMuted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => ref.read(notifScreenProvider.notifier).load(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildNotifCard(
      BuildContext context, WidgetRef ref, dynamic notif) {
    final id = (notif['_id'] ??
            notif['id'] ??
            notif['notificationId'] ??
            notif['notifId'])
        ?.toString() ??
        '';
    final title = notif['title']?.toString() ??
        notif['subject']?.toString() ??
        'Notification';
    final rawMessage = notif['message']?.toString() ??
        notif['body']?.toString() ??
        notif['description']?.toString() ??
        '';
    final isRead = notif['read'] == true || notif['isRead'] == true;
    final type = (notif['type']?.toString() ?? '').toLowerCase();
    final createdAt =
        notif['loginAt'] ?? notif['createdAt'] ?? notif['date'] ?? notif['timestamp'] ?? notif['loginTimestampUtc'];
    final message = RealtimeNotificationService.sanitizeNotificationMessage(rawMessage, createdAt);

    final (iconData, iconColor, bgColor) = _typeStyle(type);

    return GestureDetector(
      onTap: () {
        if (!isRead && id.isNotEmpty) {
          ref.read(notifScreenProvider.notifier).markRead(id);
        }
        RealtimeNotificationService.handleNotificationTap(
            context, notif is Map ? Map<String, dynamic>.from(notif) : {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead
              ? context.cardBg
              : AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead
                ? context.borderCol
                : AppColors.primary.withValues(alpha: 0.3),
            width: isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: context.isDark ? 0.15 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: context.txtPrimary,
                            fontWeight:
                                isRead ? FontWeight.w500 : FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6, right: 6, top: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (ref.watch(authProvider).isAdmin)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFEF4444),
                            size: 18,
                          ),
                          tooltip: 'Delete Notification',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: context.cardBg,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: Text(
                                  'Delete Notification',
                                  style: TextStyle(
                                    color: context.txtPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                content: Text(
                                  'Are you sure you want to delete this notification?',
                                  style: TextStyle(color: context.txtSecondary),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(color: context.txtMuted),
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF4444),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              final targetId = id.isNotEmpty
                                  ? id
                                  : (notif['_id'] ?? notif['id'] ?? notif['notificationId'])?.toString() ?? '';
                              await ref
                                  .read(notifScreenProvider.notifier)
                                  .deleteNotification(targetId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Notification deleted'),
                                    backgroundColor: Color(0xFFEF4444),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                    ],
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                          color: context.txtSecondary, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(createdAt),
                    style: TextStyle(color: context.txtMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color, Color) _typeStyle(String type) {
    final t = type.toLowerCase();
    if (t.contains('checkin') || t.contains('check_in') || t.contains('check-in')) {
      return (
        Icons.login_rounded,
        const Color(0xFF10B981),
        const Color(0xFF10B981).withValues(alpha: 0.15),
      );
    }
    if (t.contains('checkout') || t.contains('check_out') || t.contains('check-out')) {
      return (
        Icons.logout_rounded,
        const Color(0xFFF59E0B),
        const Color(0xFFF59E0B).withValues(alpha: 0.15),
      );
    }
    if (t.contains('approved') || t.contains('approve')) {
      return (
        Icons.check_circle_rounded,
        const Color(0xFF10B981),
        const Color(0xFF10B981).withValues(alpha: 0.15),
      );
    }
    if (t.contains('rejected') || t.contains('reject')) {
      return (
        Icons.cancel_rounded,
        const Color(0xFFEF4444),
        const Color(0xFFEF4444).withValues(alpha: 0.15),
      );
    }
    if (t.contains('leave')) {
      return (
        Icons.event_note_rounded,
        const Color(0xFF6366F1),
        const Color(0xFF6366F1).withValues(alpha: 0.15),
      );
    }
    if (t.contains('attend') || t.contains('check')) {
      return (
        Icons.fingerprint_rounded,
        const Color(0xFF10B981),
        const Color(0xFF10B981).withValues(alpha: 0.15),
      );
    }
    if (t.contains('salary') || t.contains('pay')) {
      return (
        Icons.payments_rounded,
        const Color(0xFF6366F1),
        const Color(0xFF6366F1).withValues(alpha: 0.15),
      );
    }
    if (type.contains('task') || type.contains('project')) {
      return (
        Icons.assignment_rounded,
        const Color(0xFF06B6D4),
        const Color(0xFF06B6D4).withValues(alpha: 0.15),
      );
    }
    if (type.contains('alert') || type.contains('warn')) {
      return (
        Icons.warning_rounded,
        const Color(0xFFEF4444),
        const Color(0xFFEF4444).withValues(alpha: 0.15),
      );
    }
    return (
      Icons.notifications_rounded,
      const Color(0xFF6366F1),
      const Color(0xFF6366F1).withValues(alpha: 0.12),
    );
  }

  String _formatTime(dynamic raw) {
    if (raw == null) return '';
    try {
      String str = raw.toString().trim();
      if (str.isEmpty) return '';
      if (str.contains('T') &&
          !str.endsWith('Z') &&
          !str.substring(str.indexOf('T')).contains('+') &&
          !str.substring(str.indexOf('T')).contains('-')) {
        str += 'Z';
      }
      final dt = DateTime.parse(str).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inSeconds < 45) return 'Just now (${DateFormat('hh:mm a').format(dt)})';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago (${DateFormat('hh:mm a').format(dt)})';
      if (diff.inHours < 24) return '${diff.inHours}h ago (${DateFormat('hh:mm a').format(dt)})';
      if (diff.inDays == 1) return 'Yesterday at ${DateFormat('hh:mm a').format(dt)}';
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return raw.toString();
    }
  }
}

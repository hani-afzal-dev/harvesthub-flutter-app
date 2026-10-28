import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/app_logger.dart';
import '../../../core/constants.dart';
import '../../../models/notification_model.dart';
import '../../../models/push_target.dart';
import '../../../providers/notification_providers.dart';
import '../../../providers/push_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../widgets/async_error_view.dart';
import '../../../widgets/load_more_button.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/app_snackbar.dart';

const Color _brand = Color(0xFF3B6D11);
const Color _brandDark = Color(0xFF2E4A0F);
const Color _textMain = Color(0xFF22301A);
const Color _textMuted = Color(0xFF6B7A5E);
const Color _tint = Color(0xFFEFF3EA);

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return DateFormat('d MMM').format(time);
}

class NotificationsScreen extends ConsumerWidget {
  final String userId;

  const NotificationsScreen({super.key, required this.userId});

  (IconData, Color) _styleFor(NotificationType type) {
    switch (type) {
      case NotificationType.newOrder:
        return (Icons.receipt_long_outlined, _brand);
      case NotificationType.restockAlert:
        return (Icons.eco_outlined, const Color(0xFF5A9A1F));
      case NotificationType.slotCancelled:
        return (Icons.event_busy_outlined, const Color(0xFFB3261E));
      case NotificationType.bookingModified:
        return (Icons.event_available_outlined, const Color(0xFF1F5FA8));
      case NotificationType.orderStatus:
        return (Icons.local_shipping_outlined, const Color(0xFF1F5FA8));
    }
  }

  Future<void> _run(
      BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e, stack) {
      AppLogger.error('Notification update failed', e, stack);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar('Could not update notifications. Try again.',
            tone: SnackTone.error),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(notificationServiceProvider);
    final notificationsAsync = ref.watch(notificationsProvider(userId));
    final limit = ref.watch(notificationLimitProvider(userId));
    final unread =
        ref.watch(unreadNotificationCountProvider(userId)).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F3),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            PageHeader(
              title: 'Notifications',
              trailing: unread == 0
                  ? null
                  : TextButton(
                      key: const ValueKey('notifications_mark_all_button'),
                      onPressed: () =>
                          _run(context, () => service.markAllRead(userId)),
                      style: TextButton.styleFrom(
                          foregroundColor: _brand,
                          minimumSize: const Size(48, 48)),
                      child: const Text('Mark all read',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
            ),
            Expanded(
              child: notificationsAsync.when(
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => AsyncErrorView(
                  message:
                      'Could not load notifications. Check your connection and try again.',
                  onRetry: () => ref.invalidate(notificationsProvider(userId)),
                ),
                data: (notifications) {
                  if (notifications.isEmpty) return const _EmptyNotifications();

                  final hasMore = notifications.length >= limit;
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: notifications.length + (hasMore ? 1 : 0),
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index == notifications.length) {
                            return LoadMoreButton(
                              onPressed: () => ref
                                  .read(notificationLimitProvider(userId)
                                      .notifier)
                                  .state += PagingRules.pageSize,
                            );
                          }
                          final n = notifications[index];
                          final style = _styleFor(n.type);
                          return _NotificationCard(
                            icon: style.$1,
                            color: style.$2,
                            heading: notificationHeading(n.type),
                            message: n.message,
                            time: _timeAgo(n.createdAt),
                            unread: !n.isRead,
                            onTap: () {
                              if (!n.isRead) {
                                _run(
                                    context, () => service.markRead(n.notifId));
                              }
                              ref
                                  .read(pendingPushTargetProvider.notifier)
                                  .state = PushTarget(
                                userId: n.userId,
                                type: n.type,
                                relatedId: n.relatedId,
                              );
                            },
                            onMarkRead: n.isRead
                                ? null
                                : () => _run(
                                    context, () => service.markRead(n.notifId)),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String heading;
  final String message;
  final String time;
  final bool unread;
  final VoidCallback onTap;
  final VoidCallback? onMarkRead;

  const _NotificationCard({
    required this.icon,
    required this.color,
    required this.heading,
    required this.message,
    required this.time,
    required this.unread,
    required this.onTap,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final markRead = onMarkRead;
    return Container(
      decoration: BoxDecoration(
        color: unread ? const Color(0xFFF3F8EC) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: unread ? const Color(0xFFD3E4BD) : Colors.transparent),
        boxShadow: [
          BoxShadow(
              color: _brandDark.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: color),
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
                              heading,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: _textMain),
                            ),
                          ),
                          if (unread)
                            Semantics(
                              label: 'Unread',
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                    color: _brand, shape: BoxShape.circle),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(message,
                          style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: Color(0xFF4C5943))),
                      const SizedBox(height: 6),
                      Text(time,
                          style:
                              const TextStyle(fontSize: 12, color: _textMuted)),
                    ],
                  ),
                ),
                if (markRead != null)
                  IconButton(
                    tooltip: 'Mark as read',
                    icon: const Icon(Icons.done_all_rounded,
                        size: 20, color: _textMuted),
                    onPressed: markRead,
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, color: _tint),
                child: Icon(Icons.notifications_none_rounded,
                    size: 44, color: _brand),
              ),
            ),
            SizedBox(height: 16),
            Text(
              "You're all caught up",
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _textMain),
            ),
            SizedBox(height: 6),
            Text(
              'Order updates and restock alerts will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

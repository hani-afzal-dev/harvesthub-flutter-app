import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../models/notification_model.dart';
import 'service_providers.dart';

final notificationLimitProvider =
    StateProvider.autoDispose.family<int, String>((ref, userId) {
  return PagingRules.pageSize;
});

final notificationsProvider = StreamProvider.autoDispose
    .family<List<NotificationModel>, String>((ref, userId) {
  final limit = ref.watch(notificationLimitProvider(userId));
  return ref
      .watch(notificationServiceProvider)
      .watchForUser(userId, limit: limit);
});

final unreadNotificationCountProvider =
    StreamProvider.autoDispose.family<int, String>((ref, userId) {
  return ref.watch(notificationServiceProvider).watchUnreadCount(userId);
});

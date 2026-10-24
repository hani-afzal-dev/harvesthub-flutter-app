import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_providers.dart';
import '../providers/session_providers.dart';

class UnreadBadge extends ConsumerWidget {
  final Widget child;

  const UnreadBadge({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return child;

    final count =
        ref.watch(unreadNotificationCountProvider(uid)).valueOrNull ?? 0;
    if (count == 0) return child;

    return Semantics(
      label: '$count unread notification${count == 1 ? '' : 's'}',
      child: Badge(
        backgroundColor: const Color(0xFFB3261E),
        label: Text(count > 99 ? '99+' : '$count'),
        child: child,
      ),
    );
  }
}

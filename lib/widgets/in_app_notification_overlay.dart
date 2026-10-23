import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../models/push_target.dart';
import '../providers/notification_providers.dart';
import '../providers/push_providers.dart';
import '../providers/session_providers.dart';

class InAppNotificationOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const InAppNotificationOverlay({super.key, required this.child});

  @override
  ConsumerState<InAppNotificationOverlay> createState() =>
      _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState
    extends ConsumerState<InAppNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _offsetAnim;
  late final Animation<double> _fadeAnim;

  final Set<String> _knownIds = {};
  bool _initialLoadDone = false;
  NotificationModel? _activeNotification;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 250),
    );
    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ));
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _showNotificationBanner(NotificationModel notification) {
    _dismissTimer?.cancel();
    HapticFeedback.mediumImpact();

    setState(() {
      _activeNotification = notification;
    });

    _animController.forward(from: 0.0);

    _dismissTimer = Timer(const Duration(seconds: 4), () {
      _dismissBanner();
    });
  }

  void _dismissBanner() {
    _dismissTimer?.cancel();
    if (!mounted) return;
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _activeNotification = null;
        });
      }
    });
  }

  void _onBannerTapped() {
    final notif = _activeNotification;
    _dismissBanner();
    if (notif == null) return;

    ref.read(pendingPushTargetProvider.notifier).state = PushTarget(
      userId: notif.userId,
      type: notif.type,
      relatedId: notif.relatedId,
    );
  }

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.restockAlert:
        return Icons.inventory_2_outlined;
      case NotificationType.newOrder:
        return Icons.shopping_bag_outlined;
      case NotificationType.slotCancelled:
        return Icons.event_busy_outlined;
      case NotificationType.bookingModified:
        return Icons.schedule_outlined;
      case NotificationType.orderStatus:
        return Icons.local_shipping_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);

    if (uid != null && uid.isNotEmpty) {
      ref.listen<AsyncValue<List<NotificationModel>>>(
        notificationsProvider(uid),
        (previous, next) {
          final list = next.valueOrNull;
          if (list == null) return;

          if (!_initialLoadDone) {
            _knownIds.addAll(list.map((n) => n.notifId));
            _initialLoadDone = true;
            return;
          }

          final now = DateTime.now();
          for (final notif in list) {
            if (!_knownIds.contains(notif.notifId)) {
              _knownIds.add(notif.notifId);
              // Only trigger if notification is fresh (within last 2 minutes)
              final age = now.difference(notif.createdAt).inSeconds;
              if (age < 120 && !notif.isRead) {
                _showNotificationBanner(notif);
                break;
              }
            }
          }
        },
      );
    }

    return Stack(
      children: [
        widget.child,
        if (_activeNotification != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: SlideTransition(
                position: _offsetAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    child: GestureDetector(
                      onTap: _onBannerTapped,
                      onVerticalDragUpdate: (details) {
                        if (details.primaryDelta != null &&
                            details.primaryDelta! < -6) {
                          _dismissBanner();
                        }
                      },
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFF3B6D11).withValues(alpha: 0.18),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B6D11)
                                      .withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _iconForType(_activeNotification!.type),
                                  color: const Color(0xFF3B6D11),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            notificationHeading(
                                                _activeNotification!.type),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: Color(0xFF22301A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Just now',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF8A9A7E),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _activeNotification!.message,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF4C5943),
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Color(0xFF8A9A7E),
                                ),
                                onPressed: _dismissBanner,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

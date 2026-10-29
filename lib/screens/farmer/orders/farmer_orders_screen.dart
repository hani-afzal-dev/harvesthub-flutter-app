import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';
import '../../../core/order_number.dart';
import '../../../models/order_model.dart';
import '../../../providers/farmer_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/async_error_view.dart';
import '../../../widgets/load_more_button.dart';
import '../../../widgets/panel_ui.dart';

class _StatusStyle {
  final String label;
  final IconData icon;
  final Color color;
  final Color background;

  const _StatusStyle(this.label, this.icon, this.color, this.background);
}

_StatusStyle _styleFor(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return const _StatusStyle('New', Icons.hourglass_top_rounded,
          PanelColors.amber, PanelColors.amberBg);
    case OrderStatus.confirmed:
      return const _StatusStyle('Confirmed', Icons.thumb_up_alt_outlined,
          PanelColors.blue, PanelColors.blueBg);
    case OrderStatus.readyForPickup:
      return const _StatusStyle('Ready for pickup', Icons.shopping_bag_outlined,
          PanelColors.brand, PanelColors.tint);
    case OrderStatus.completed:
      return const _StatusStyle('Picked up', Icons.check_circle_outline_rounded,
          PanelColors.textMuted, PanelColors.greyBg);
    case OrderStatus.cancelled:
      return const _StatusStyle('Cancelled', Icons.cancel_outlined,
          PanelColors.danger, PanelColors.dangerBg);
  }
}

class FarmerOrdersScreen extends ConsumerStatefulWidget {
  final String farmerId;

  const FarmerOrdersScreen({super.key, required this.farmerId});

  @override
  ConsumerState<FarmerOrdersScreen> createState() => _FarmerOrdersScreenState();
}

class _FarmerOrdersScreenState extends ConsumerState<FarmerOrdersScreen> {
  static const _filterLabels = [
    'Active',
    'New',
    'Confirmed',
    'Ready',
    'Completed',
    'Cancelled',
    'All',
  ];

  int _filter = 0;
  final Set<String> _busy = {};

  bool _matches(OrderModel order, int filter) {
    switch (filter) {
      case 0:
        return order.status == OrderStatus.pending ||
            order.status == OrderStatus.confirmed ||
            order.status == OrderStatus.readyForPickup;
      case 1:
        return order.status == OrderStatus.pending;
      case 2:
        return order.status == OrderStatus.confirmed;
      case 3:
        return order.status == OrderStatus.readyForPickup;
      case 4:
        return order.status == OrderStatus.completed;
      case 5:
        return order.status == OrderStatus.cancelled;
      default:
        return true;
    }
  }

  Future<void> _updateStatus(OrderModel order, OrderStatus status) async {
    if (_busy.contains(order.orderId)) return;
    final number = orderNumber(order.orderId);

    if (status == OrderStatus.cancelled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Cancel order $number?'),
          content: const Text(
              'The customer will be notified and the stock goes back to your shop.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep order')),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: PanelColors.danger),
              child: const Text('Cancel order'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    HapticFeedback.lightImpact();
    setState(() => _busy.add(order.orderId));
    try {
      await ref.read(orderServiceProvider).updateStatus(order.orderId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
        'Order $number is now ${_styleFor(status).label.toLowerCase()}',
        tone: SnackTone.success,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
          'Could not update order $number. Try again.',
          tone: SnackTone.error));
    } finally {
      if (mounted) setState(() => _busy.remove(order.orderId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(farmerOrdersProvider(widget.farmerId));
    final limit = ref.watch(farmerOrderLimitProvider(widget.farmerId));

    Widget body;
    if (ordersAsync.hasError && !ordersAsync.hasValue) {
      body = AsyncErrorView(
        title: 'Orders did not load',
        message: 'Check your connection and try again.',
        onRetry: () => ref.invalidate(farmerOrdersProvider(widget.farmerId)),
      );
    } else if (!ordersAsync.hasValue) {
      body = const Center(
          child: CircularProgressIndicator(color: PanelColors.brand));
    } else {
      final orders = ordersAsync.value!;
      if (orders.isEmpty) {
        body = const PanelEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No orders yet',
          message:
              'New orders from customers show up here. Keep your products stocked and visible.',
        );
      } else {
        final counts = List<int>.generate(
          _filterLabels.length,
          (i) => orders.where((o) => _matches(o, i)).length,
        );
        final visible = orders.where((o) => _matches(o, _filter)).toList();
        final hasMore = orders.length >= limit;

        body = CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              sliver: SliverToBoxAdapter(
                child: PanelStatStrip(stats: [
                  ('${counts[1]}', 'New'),
                  ('${counts[2]}', 'To prepare'),
                  ('${counts[3]}', 'Ready'),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: FilterChipBar(
                labels: _filterLabels,
                counts: counts,
                selected: _filter,
                onSelected: (i) => setState(() => _filter = i),
              ),
            ),
            if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: PanelEmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: _filter == 0 ? 'All caught up' : 'Nothing here',
                  message: _filter == 0
                      ? 'No orders need your attention right now.'
                      : 'No orders match this filter.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                sliver: SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final order = visible[index];
                    return _OrderCard(
                      key: ValueKey('farmer_order_${order.orderId}'),
                      order: order,
                      busy: _busy.contains(order.orderId),
                      onUpdateStatus: (status) => _updateStatus(order, status),
                    );
                  },
                ),
              ),
            if (hasMore)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: LoadMoreButton(
                    onPressed: () => ref
                        .read(
                            farmerOrderLimitProvider(widget.farmerId).notifier)
                        .state += PagingRules.pageSize,
                  ),
                ),
              ),
          ],
        );
      }
    }

    var subtitle = 'Confirm, prepare and hand over orders';
    final orders = ordersAsync.valueOrNull;
    if (orders != null) {
      var waiting = 0;
      for (final order in orders) {
        if (order.status == OrderStatus.pending) waiting++;
      }
      if (waiting > 0) {
        subtitle =
            '$waiting new ${waiting == 1 ? 'order needs' : 'orders need'} your reply';
      }
    }

    return Scaffold(
      backgroundColor: PanelColors.pageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            PanelHeader(title: 'Orders', subtitle: subtitle),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final bool busy;
  final ValueChanged<OrderStatus> onUpdateStatus;

  const _OrderCard({
    super.key,
    required this.order,
    required this.busy,
    required this.onUpdateStatus,
  });

  static final _timeFormat = DateFormat('h:mm\u00A0a');
  static final _dayFormat = DateFormat('EEE, MMM d');

  String _dayLabel(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return _dayFormat.format(time);
  }

  (OrderStatus, String, IconData)? get _nextStep {
    switch (order.status) {
      case OrderStatus.pending:
        return (
          OrderStatus.confirmed,
          'Confirm order',
          Icons.thumb_up_alt_outlined
        );
      case OrderStatus.confirmed:
        return (
          OrderStatus.readyForPickup,
          'Mark ready',
          Icons.shopping_bag_outlined
        );
      case OrderStatus.readyForPickup:
        return (OrderStatus.completed, 'Mark picked up', Icons.check_rounded);
      case OrderStatus.completed:
      case OrderStatus.cancelled:
        return null;
    }
  }

  int get _stepIndex {
    switch (order.status) {
      case OrderStatus.pending:
        return 1;
      case OrderStatus.confirmed:
        return 2;
      case OrderStatus.readyForPickup:
        return 3;
      case OrderStatus.completed:
        return 4;
      case OrderStatus.cancelled:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(order.status);
    final next = _nextStep;
    final canCancel = order.status == OrderStatus.pending ||
        order.status == OrderStatus.confirmed;
    final pickup = order.pickupSlotTime;
    final isActive = next != null;
    final pickupToday = pickup != null && _dayLabel(pickup) == 'Today';

    return PanelCard(
      borderColor:
          order.status == OrderStatus.pending ? const Color(0xFFF1D7A8) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order ${orderNumber(order.orderId)}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: PanelColors.textMain),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Placed ${_dayLabel(order.createdAt)}, ${_timeFormat.format(order.createdAt)}',
                      style: const TextStyle(
                          fontSize: 12, color: PanelColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(
                label: style.label,
                icon: style.icon,
                color: style.color,
                background: style.background,
              ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 12),
            Semantics(
              label: 'Step $_stepIndex of 4',
              child: Row(
                children: [
                  for (var i = 1; i <= 4; i++) ...[
                    Expanded(
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: i <= _stepIndex
                              ? PanelColors.brand
                              : PanelColors.border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    if (i < 4) const SizedBox(width: 4),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (order.customerName.trim().isNotEmpty) ...[
            _InfoRow(
              icon: Icons.person_outline_rounded,
              label: 'Customer',
              value: order.customerName.trim(),
            ),
            const SizedBox(height: 6),
          ],
          if (pickup != null)
            _InfoRow(
              icon: Icons.event_available_rounded,
              label: 'Pickup',
              value: '${_dayLabel(pickup)} · ${_timeFormat.format(pickup)}',
              highlight: pickupToday && isActive,
            ),
          if (order.deliveryAddr.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.place_outlined,
              label: 'Address',
              value: order.deliveryAddr.trim(),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: PanelColors.pageBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: PanelColors.border),
                          ),
                          child: Text(
                            '${item.qty}×',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: PanelColors.brand,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.itemName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: PanelColors.textMain),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Rs. ${item.subtotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: PanelColors.textBody,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text('Order total',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: PanelColors.textMain)),
              ),
              Text(
                'Rs. ${order.totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: PanelColors.brand,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (order.hasDiscount) ...[
            const SizedBox(height: 4),
            Text(
              'Customer used ${order.promoCode ?? 'a promo'} (−Rs. ${order.discount.toStringAsFixed(0)}). HarvestHub covers the discount.',
              style: const TextStyle(
                  fontSize: 12, height: 1.4, color: PanelColors.textMuted),
            ),
          ],
          if (next != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (canCancel) ...[
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      key: ValueKey('farmer_order_cancel_${order.orderId}'),
                      onPressed: busy
                          ? null
                          : () => onUpdateStatus(OrderStatus.cancelled),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PanelColors.danger,
                        minimumSize: const Size(0, 48),
                        side: const BorderSide(color: Color(0xFFF0B4B4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    key: ValueKey('farmer_order_next_${order.orderId}'),
                    onPressed: busy ? null : () => onUpdateStatus(next.$1),
                    style: FilledButton.styleFrom(
                      backgroundColor: PanelColors.brand,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: PanelColors.brand),
                          )
                        : Icon(next.$3, size: 18),
                    label: Text(
                      next.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? PanelColors.amber : PanelColors.textMuted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: '$label  ',
              style: TextStyle(fontSize: 13, color: color),
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: highlight ? PanelColors.amber : PanelColors.textMain,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

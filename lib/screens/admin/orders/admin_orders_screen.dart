import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';
import '../../../core/order_number.dart';
import '../../../models/order_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/admin_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/async_error_view.dart';
import '../../../widgets/load_more_button.dart';
import '../../../widgets/panel_ui.dart';

final _timeFormat = DateFormat('h:mm\u00A0a');
final _dayFormat = DateFormat('EEE, MMM d');
final _money = NumberFormat('#,##0');

String _dayLabel(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff =
      DateTime(time.year, time.month, time.day).difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return _dayFormat.format(time);
}

(String, IconData, Color, Color) _statusStyle(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return (
        'Pending',
        Icons.hourglass_top_rounded,
        PanelColors.amber,
        PanelColors.amberBg
      );
    case OrderStatus.confirmed:
      return (
        'Confirmed',
        Icons.thumb_up_alt_outlined,
        PanelColors.blue,
        PanelColors.blueBg
      );
    case OrderStatus.readyForPickup:
      return (
        'Ready for pickup',
        Icons.shopping_bag_outlined,
        PanelColors.brand,
        PanelColors.tint
      );
    case OrderStatus.completed:
      return (
        'Completed',
        Icons.check_circle_outline_rounded,
        PanelColors.textMuted,
        PanelColors.greyBg
      );
    case OrderStatus.cancelled:
      return (
        'Cancelled',
        Icons.cancel_outlined,
        PanelColors.danger,
        PanelColors.dangerBg
      );
  }
}

bool _isActive(OrderStatus status) =>
    status == OrderStatus.pending ||
    status == OrderStatus.confirmed ||
    status == OrderStatus.readyForPickup;

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  static const _filterLabels = [
    'Active',
    'Pending',
    'Confirmed',
    'Ready',
    'Completed',
    'Cancelled',
    'All',
  ];

  final _searchController = TextEditingController();
  final Set<String> _busy = {};
  String _query = '';
  int _filter = 6;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesFilter(OrderModel order, int filter) {
    switch (filter) {
      case 0:
        return _isActive(order.status);
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

  Future<void> _cancel(OrderModel order) async {
    if (_busy.contains(order.orderId)) return;
    final number = orderNumber(order.orderId);
    final confirmed = await showPanelConfirm(
      context,
      title: 'Cancel order $number?',
      message:
          'The customer is notified, stock goes back to the farmer and any booked pickup spot is freed.',
      confirmLabel: 'Cancel order',
      cancelLabel: 'Keep order',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy.add(order.orderId));
    try {
      await ref.read(orderServiceProvider).cancelOrder(order.orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar('Order $number cancelled', tone: SnackTone.success));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
          'Could not cancel order $number. Try again.',
          tone: SnackTone.error));
    } finally {
      if (mounted) setState(() => _busy.remove(order.orderId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(adminOrdersProvider);
    final limit = ref.watch(adminOrderLimitProvider);
    final farmerNames = <String, String>{};
    for (final farmer
        in ref.watch(adminFarmerProfilesProvider).valueOrNull ?? const []) {
      farmerNames[farmer.farmerId] = farmer.businessName;
    }
    final customerNames = <String, String>{};
    for (final user
        in ref.watch(adminUsersByRoleProvider(UserRole.customer)).valueOrNull ??
            const <UserModel>[]) {
      customerNames[user.userId] = user.name;
    }

    Widget body;
    if (ordersAsync.hasError && !ordersAsync.hasValue) {
      body = AsyncErrorView(
        message: 'Could not load orders.',
        onRetry: () => ref.invalidate(adminOrdersProvider),
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
              'Orders from every farm show up here once customers start buying.',
        );
      } else {
        final searched = orders
            .where((o) => matchesSearch(_query, [
                  orderNumber(o.orderId),
                  farmerNames[o.farmerId] ?? '',
                  customerNames[o.customerId] ?? o.customerName,
                ]))
            .toList();
        final counts = List<int>.generate(_filterLabels.length,
            (i) => searched.where((o) => _matchesFilter(o, i)).length);
        final visible =
            searched.where((o) => _matchesFilter(o, _filter)).toList();
        final hasMore = orders.length >= limit;

        var activeValue = 0.0;
        for (final order in orders) {
          if (_isActive(order.status)) activeValue += order.totalPrice;
        }

        body = CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              sliver: SliverToBoxAdapter(
                child: PanelStatStrip(
                  stats: [
                    ('${counts[0]}', 'In progress'),
                    (
                      'Rs. ${_money.format(activeValue.round())}',
                      'Open value'
                    ),
                    ('${counts[5]}', 'Cancelled'),
                  ],
                  icons: const [
                    Icons.hourglass_top_rounded,
                    Icons.account_balance_wallet_outlined,
                    Icons.cancel_outlined,
                  ],
                  valueColors: const [
                    PanelColors.amber,
                    PanelColors.brand,
                    PanelColors.danger,
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: PanelSearchField(
                controller: _searchController,
                hint: 'Search order #, farm or customer',
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  FilterChipBar(
                    labels: _filterLabels,
                    counts: counts,
                    selected: _filter,
                    onSelected: (i) => setState(() => _filter = i),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Container(
                        width: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              PanelColors.pageBg.withValues(alpha: 0),
                              PanelColors.pageBg,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (visible.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: PanelEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matches',
                  message: 'Try a different search or filter.',
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
                      key: ValueKey('admin_order_${order.orderId}'),
                      order: order,
                      farmerName: farmerNames[order.farmerId],
                      customerName: customerNames[order.customerId] ??
                          (order.customerName.isEmpty
                              ? null
                              : order.customerName),
                      busy: _busy.contains(order.orderId),
                      onCancel: () => _cancel(order),
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
                        .read(adminOrderLimitProvider.notifier)
                        .state += PagingRules.pageSize,
                  ),
                ),
              ),
          ],
        );
      }
    }

    return Scaffold(
      backgroundColor: PanelColors.pageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const PanelHeader(
              title: 'Orders',
              subtitle: 'Every order across all farms',
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final OrderModel order;
  final String? farmerName;
  final String? customerName;
  final bool busy;
  final VoidCallback onCancel;

  const _OrderCard({
    super.key,
    required this.order,
    required this.farmerName,
    required this.customerName,
    required this.busy,
    required this.onCancel,
  });

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _showAllItems = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final farmerName = widget.farmerName;
    final customerName = widget.customerName;
    final busy = widget.busy;
    final onCancel = widget.onCancel;
    final style = _statusStyle(order.status);
    final pickup = order.pickupSlotTime;
    final visibleItems =
        _showAllItems ? order.items : order.items.take(3).toList();
    final hiddenCount = order.items.length - visibleItems.length;

    return PanelCard(
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
                label: style.$1,
                icon: style.$2,
                color: style.$3,
                background: style.$4,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: PanelColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PartyRow(
                  icon: Icons.storefront_outlined,
                  label: 'Farm',
                  value: farmerName ?? 'Unknown farm',
                ),
                const SizedBox(height: 8),
                _PartyRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Customer',
                  value: customerName ?? 'Unknown customer',
                ),
                if (pickup != null) ...[
                  const SizedBox(height: 8),
                  _PartyRow(
                    icon: Icons.event_available_rounded,
                    label: 'Pickup',
                    value:
                        '${_dayLabel(pickup)} · ${_timeFormat.format(pickup)}',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            decoration: BoxDecoration(
              color: PanelColors.pageBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in visibleItems)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Text(
                          '${item.qty}×',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: PanelColors.brand,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(item.itemName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: PanelColors.textMain)),
                        ),
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
                if (hiddenCount > 0 || _showAllItems)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _showAllItems = !_showAllItems),
                      style: TextButton.styleFrom(
                        foregroundColor: PanelColors.brand,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 40),
                      ),
                      child: Text(_showAllItems
                          ? 'Show less'
                          : 'Show $hiddenCount more item${hiddenCount == 1 ? '' : 's'}'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: PanelColors.border),
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
          if (order.hasDiscount)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Promo ${order.promoCode ?? ''}: −Rs. ${order.discount.toStringAsFixed(0)}, covered by HarvestHub',
                style:
                    const TextStyle(fontSize: 12, color: PanelColors.textMuted),
              ),
            ),
          if (_isActive(order.status)) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: ValueKey('admin_order_cancel_${order.orderId}'),
                onPressed: busy ? null : onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: PanelColors.danger,
                  minimumSize: const Size(0, 44),
                  side: const BorderSide(color: Color(0xFFF0B4B4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: PanelColors.danger),
                      )
                    : const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancel order',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PartyRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PartyRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: PanelColors.textMuted),
        const SizedBox(width: 8),
        SizedBox(
          width: 84,
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 13, color: PanelColors.textMuted)),
        ),
        Expanded(
          child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: PanelColors.textMain)),
        ),
      ],
    );
  }
}

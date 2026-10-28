import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';
import '../../../models/order_model.dart';
import '../../../providers/order_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../providers/session_providers.dart';
import '../../../services/order_service.dart';
import '../../../widgets/async_error_view.dart';
import '../../../widgets/load_more_button.dart';
import '../../../widgets/offline_banner.dart';
import '../../../widgets/star_rating_widget.dart';
import 'modify_pickup_sheet.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../core/order_number.dart';

const Color _brand = Color(0xFF3B6D11);
const Color _brandDark = Color(0xFF2E4A0F);
const Color _textMain = Color(0xFF22301A);
const Color _textMuted = Color(0xFF6B7A5E);
const Color _tint = Color(0xFFEFF3EA);
const Color _pageBg = Color(0xFFF6F8F3);
const Color _danger = Color(0xFFD64545);

final _pickupFormat = DateFormat('EEE, MMM d · h:mm\u00A0a');
final _placedFormat = DateFormat('MMM d, yyyy · h:mm\u00A0a');

const List<(String?, String)> _filters = [
  (null, 'All'),
  (OrderStatusValues.pending, 'Pending'),
  (OrderStatusValues.confirmed, 'Confirmed'),
  (OrderStatusValues.readyForPickup, 'Ready'),
  (OrderStatusValues.completed, 'Completed'),
  (OrderStatusValues.cancelled, 'Cancelled'),
];

class OrderHistoryScreen extends ConsumerWidget {
  final VoidCallback? onBack;

  const OrderHistoryScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);

    if (uid == null) {
      return const Scaffold(
          body: Center(child: Text('Please log in to view your orders.')));
    }

    final ordersAsync = ref.watch(customerOrdersProvider(uid));
    final limit = ref.watch(customerOrderLimitProvider(uid));
    final statusFilter = ref.watch(customerOrderStatusFilterProvider(uid));

    String filterLabel = 'All';
    for (final filter in _filters) {
      if (filter.$1 == statusFilter) filterLabel = filter.$2;
    }

    VoidCallback? backAction = onBack;
    if (backAction == null && Navigator.of(context).canPop()) {
      backAction = () => Navigator.of(context).pop();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _pageBg,
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE3E9DA))),
                ),
                padding:
                    EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
                      child: Row(
                        children: [
                          if (backAction != null)
                            Semantics(
                              button: true,
                              label: 'Back',
                              child: InkWell(
                                onTap: backAction,
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Center(
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _brandDark.withValues(
                                                alpha: 0.08),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                          Icons.chevron_left_rounded,
                                          color: _textMain),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'My Orders',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: _brand),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 56,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        itemCount: _filters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final filter = _filters[index];
                          final selected = filter.$1 == statusFilter;
                          return Semantics(
                            button: true,
                            selected: selected,
                            label: '${filter.$2} orders',
                            excludeSemantics: true,
                            child: Material(
                              color: selected ? _brand : _tint,
                              borderRadius: BorderRadius.circular(24),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => ref
                                    .read(customerOrderStatusFilterProvider(uid)
                                        .notifier)
                                    .state = filter.$1,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18),
                                  child: Center(
                                    child: Text(
                                      filter.$2,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: selected
                                            ? Colors.white
                                            : _textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ordersAsync.when(
                  skipLoadingOnReload: true,
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) {
                    final cached = ref
                            .watch(cachedCustomerOrdersProvider(uid))
                            .valueOrNull ??
                        const <OrderModel>[];
                    final saved = <OrderModel>[];
                    for (final order in cached) {
                      if (statusFilter == null ||
                          orderStatusToString(order.status) == statusFilter) {
                        saved.add(order);
                      }
                    }
                    if (saved.isEmpty) {
                      return AsyncErrorView(
                        message:
                            'Could not load your orders. Check your connection and try again.',
                        onRetry: () =>
                            ref.invalidate(customerOrdersProvider(uid)),
                      );
                    }
                    return Column(
                      children: [
                        const OfflineNotice(
                            message:
                                'Could not refresh. Showing your saved orders.'),
                        Expanded(child: _OrderList(orders: saved)),
                      ],
                    );
                  },
                  data: (orders) {
                    var staleFilter = false;
                    for (final order in orders) {
                      if (statusFilter != null &&
                          orderStatusToString(order.status) != statusFilter) {
                        staleFilter = true;
                      }
                    }
                    if (staleFilter && ordersAsync.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (orders.isEmpty) {
                      return _EmptyOrders(
                        filterLabel: statusFilter == null ? null : filterLabel,
                        onBrowse: onBack,
                      );
                    }
                    return _OrderList(
                      orders: orders,
                      onLoadMore: orders.length >= limit
                          ? () => ref
                              .read(customerOrderLimitProvider(uid).notifier)
                              .state += PagingRules.pageSize
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  final String? filterLabel;
  final VoidCallback? onBrowse;

  const _EmptyOrders({required this.filterLabel, required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    final label = filterLabel;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration:
                  const BoxDecoration(shape: BoxShape.circle, color: _tint),
              child: const Icon(Icons.receipt_long_outlined,
                  size: 44, color: _brand),
            ),
            const SizedBox(height: 16),
            Text(
              label == null
                  ? 'No orders yet'
                  : 'No ${label.toLowerCase()} orders',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _textMain),
            ),
            const SizedBox(height: 6),
            Text(
              label == null
                  ? 'Your orders will show up here once you place one.'
                  : 'Try another filter to see your other orders.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textMuted),
            ),
            if (label == null && onBrowse != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onBrowse,
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  minimumSize: const Size(180, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Browse produce'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<OrderModel> orders;
  final VoidCallback? onLoadMore;

  const _OrderList({required this.orders, this.onLoadMore});

  @override
  Widget build(BuildContext context) {
    final loadMore = onLoadMore;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          itemCount: orders.length + (loadMore == null ? 0 : 1),
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            if (index == orders.length && loadMore != null) {
              return LoadMoreButton(onPressed: loadMore);
            }
            return _OrderCard(
                key: ValueKey(orders[index].orderId), order: orders[index]);
          },
        ),
      ),
    );
  }
}

class _OrderCard extends ConsumerStatefulWidget {
  final OrderModel order;
  const _OrderCard({super.key, required this.order});

  @override
  ConsumerState<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<_OrderCard> {
  int _selectedStars = 0;
  bool _busy = false;
  bool _showAllItems = false;

  OrderModel get order => widget.order;

  bool get _canEdit =>
      order.status == OrderStatus.pending ||
      order.status == OrderStatus.confirmed;

  void _showMessage(String message, {SnackTone tone = SnackTone.error}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(appSnackBar(message, tone: tone));
  }

  Future<void> _run(
      Future<void> Function() action, String successMessage) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _showMessage(successMessage, tone: SnackTone.success);
    } on OrderNotEditableException catch (e) {
      _showMessage(e.toString());
    } on SlotFullDuringCheckoutException catch (e) {
      _showMessage(e.toString());
    } on RatingNotAllowedException catch (e) {
      _showMessage(e.toString());
    } catch (_) {
      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text(
            'Items will go back to stock and the farmer will be told.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep order')),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD64545)),
              child: const Text('Cancel order')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
        () => ref.read(orderServiceProvider).cancelOwnOrder(order.orderId),
        'Order cancelled.');
  }

  Future<void> _pickNewSlot() async {
    final slotId = await ModifyPickupSheet.show(
      context,
      farmerId: order.farmerId,
      currentSlotId: order.pickupSlotId,
      currentSlotTime: order.pickupSlotTime,
    );
    if (slotId == null) return;
    await _run(
      () => ref
          .read(orderServiceProvider)
          .modifyPickupSlot(orderId: order.orderId, newSlotId: slotId),
      'Pickup slot updated.',
    );
  }

  Future<void> _submitRating() async {
    if (_selectedStars == 0) return;
    await _run(
      () => ref
          .read(orderServiceProvider)
          .submitRating(orderId: order.orderId, stars: _selectedStars),
      'Thanks for rating.',
    );
  }

  (String, IconData, Color, Color) _statusStyle(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return (
          'Pending',
          Icons.hourglass_top_rounded,
          const Color(0xFF8A5A0B),
          const Color(0xFFFDF0DC)
        );
      case OrderStatus.confirmed:
        return (
          'Confirmed',
          Icons.thumb_up_alt_outlined,
          const Color(0xFF1F5FA8),
          const Color(0xFFE3EEFB)
        );
      case OrderStatus.readyForPickup:
        return (
          'Ready for pickup',
          Icons.shopping_bag_outlined,
          _brand,
          const Color(0xFFE6EEDC)
        );
      case OrderStatus.completed:
        return (
          'Completed',
          Icons.check_circle_outline,
          _brand,
          const Color(0xFFE6EEDC)
        );
      case OrderStatus.cancelled:
        return (
          'Cancelled',
          Icons.cancel_outlined,
          const Color(0xFFB3261E),
          const Color(0xFFFCE8E8)
        );
    }
  }

  Widget _infoLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: _textMuted),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '$label ',
                style: const TextStyle(fontSize: 13, color: _textMuted),
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: _textMain),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusStyle(order.status);
    final isActive = order.status == OrderStatus.pending ||
        order.status == OrderStatus.confirmed ||
        order.status == OrderStatus.readyForPickup;
    final pickupTime = order.pickupSlotTime;

    final infoLines = <Widget>[];
    final visibleItems =
        _showAllItems ? order.items : order.items.take(3).toList();
    final hiddenCount = order.items.length - visibleItems.length;
    if (!isActive) {
      if (order.status == OrderStatus.completed) {
        infoLines.add(_infoLine(Icons.schedule_rounded, 'Picked up',
            _pickupFormat.format(order.updatedAt)));
      } else {
        infoLines.add(_infoLine(Icons.event_busy_outlined, 'Cancelled',
            _pickupFormat.format(order.updatedAt)));
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: _brandDark.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'Order ',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _textMain),
                    children: [
                      TextSpan(
                        text: orderNumber(order.orderId),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, color: _textMuted),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: status.$4,
                      borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(status.$2, size: 14, color: status.$3),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          status.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: status.$3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _placedFormat.format(order.createdAt),
            semanticsLabel: 'Placed ${_placedFormat.format(order.createdAt)}',
            style: const TextStyle(fontSize: 13, color: _textMuted),
          ),
          if (isActive) ...[
            const SizedBox(height: 12),
            _PickupBanner(
                time: pickupTime == null
                    ? null
                    : _pickupFormat.format(pickupTime)),
            const SizedBox(height: 16),
            _ProgressTracker(status: order.status),
          ] else ...[
            const SizedBox(height: 8),
            ...infoLines,
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
                color: const Color(0xFFEFF3EA),
                borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in visibleItems)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.itemName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _textMain),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'x${item.qty}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _textMuted),
                        ),
                      ],
                    ),
                  ),
                if (hiddenCount > 0 || _showAllItems)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: ValueKey('order_items_toggle_${order.orderId}'),
                      onPressed: () =>
                          setState(() => _showAllItems = !_showAllItems),
                      style: TextButton.styleFrom(
                        foregroundColor: _brand,
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
          if (order.hasDiscount)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Promo ${order.promoCode ?? ''}',
                      style: const TextStyle(fontSize: 13, color: _brand),
                    ),
                  ),
                  Text(
                    '− Rs. ${order.discount.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 13, color: _brand),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              const Expanded(
                child: Text('Total',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _textMain)),
              ),
              Text(
                'Rs. ${order.amountPayable.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _brand,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (_canEdit) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: ValueKey('order_change_slot_${order.orderId}'),
                    onPressed: _busy ? null : _pickNewSlot,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _brand,
                      minimumSize: const Size(0, 44),
                      side: const BorderSide(color: Color(0xFFE3E9DA)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Change slot',
                      semanticsLabel: 'Change pickup slot',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    key: ValueKey('order_cancel_${order.orderId}'),
                    onPressed: _busy ? null : _confirmCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _danger,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      side: const BorderSide(color: Color(0xFFF0B4B4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Cancel order',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (order.status == OrderStatus.completed) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
              decoration: BoxDecoration(
                  color: const Color(0xFFEFF3EA),
                  borderRadius: BorderRadius.circular(14)),
              child: order.customerRating != null
                  ? _RatingSummary(stars: order.customerRating!)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('Rate this order',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _textMuted)),
                        ),
                        StarRatingWidget(
                          value: _selectedStars,
                          onChanged: _busy
                              ? null
                              : (stars) =>
                                  setState(() => _selectedStars = stars),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          alignment: Alignment.topCenter,
                          child: _selectedStars == 0
                              ? const SizedBox(width: double.infinity)
                              : Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton(
                                    onPressed: _busy ? null : _submitRating,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _brand,
                                      minimumSize: const Size(0, 44),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Submit rating'),
                                  ),
                                ),
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PickupBanner extends StatelessWidget {
  final String? time;

  const _PickupBanner({required this.time});

  @override
  Widget build(BuildContext context) {
    final value = time;
    const amber = Color(0xFF8A5A0B);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color:
            value != null ? const Color(0xFFE6EEDC) : const Color(0xFFFDF2E3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            value != null
                ? Icons.schedule_rounded
                : Icons.hourglass_top_rounded,
            size: 20,
            color: value != null ? _brand : amber,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: value != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pickup time',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _brand)),
                      Text(value,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _textMain)),
                    ],
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pickup time not set yet',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: amber)),
                      Text('The farmer will confirm it soon.',
                          style: TextStyle(fontSize: 12, color: amber)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RatingSummary extends StatelessWidget {
  final int stars;

  const _RatingSummary({required this.stars});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Your rating: $stars out of 5 stars',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Expanded(
              child: Text('Your rating',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _textMuted)),
            ),
            Text(
              stars.toStringAsFixed(1),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: _textMain),
            ),
            const SizedBox(width: 8),
            for (var i = 0; i < 5; i++)
              Icon(
                i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                size: 20,
                color: const Color(0xFFEF9F27),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProgressTracker extends StatelessWidget {
  final OrderStatus status;

  const _ProgressTracker({required this.status});

  Widget _line({required bool visible, required bool filled}) {
    Color color = const Color(0xFFE1E7D8);
    if (!visible) {
      color = Colors.transparent;
    } else if (filled) {
      color = _brand;
    }
    return Container(height: 3, color: color);
  }

  @override
  Widget build(BuildContext context) {
    var reached = 0;
    if (status == OrderStatus.confirmed) reached = 1;
    if (status == OrderStatus.readyForPickup) reached = 2;

    const steps = [
      ('Placed', Icons.receipt_outlined),
      ('Confirmed', Icons.thumb_up_alt_outlined),
      ('Ready', Icons.shopping_bag_outlined),
      ('Picked up', Icons.check_rounded),
    ];

    return Semantics(
      label: 'Order progress: ${steps[reached].$1}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: _line(visible: i > 0, filled: i <= reached)),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              i <= reached ? _brand : const Color(0xFFEFF3EA),
                          border: Border.all(
                            color:
                                i <= reached ? _brand : const Color(0xFFD5DDCB),
                          ),
                        ),
                        child: Icon(
                          i <= reached ? Icons.check_rounded : steps[i].$2,
                          size: 15,
                          color: i <= reached
                              ? Colors.white
                              : const Color(0xFF9AA590),
                        ),
                      ),
                      Expanded(
                        child: _line(
                            visible: i < steps.length - 1, filled: i < reached),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[i].$1,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: i <= reached ? _textMain : _textMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

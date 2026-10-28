import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/cart_item.dart';
import '../../../models/pickup_slot_model.dart';
import '../../../providers/cart_providers.dart';
import '../../../providers/checkout_providers.dart';
import '../../../providers/navigation_providers.dart';
import '../../../providers/pickup_providers.dart';
import '../../../providers/promo_providers.dart';
import '../../../providers/session_providers.dart';
import '../../../providers/verification_providers.dart';
import '../../../services/order_service.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/page_header.dart';
import '../../../services/push_permission.dart';

const Color _brand = Color(0xFF3B6D11);
const Color _brandDark = Color(0xFF2E4A0F);
const Color _textMain = Color(0xFF22301A);
const Color _textMuted = Color(0xFF6B7A5E);
const Color _tint = Color(0xFFEFF3EA);
const Color _danger = Color(0xFFD64545);

final _slotDay = DateFormat('EEE, d MMM');
final _slotTime = DateFormat('h:mm\u00A0a');

String _rupees(double amount) => 'Rs. ${amount.toStringAsFixed(0)}';

class CheckoutScreen extends ConsumerWidget {
  final List<CartLine> lines;
  final double subtotal;

  const CheckoutScreen(
      {super.key, required this.lines, required this.subtotal});

  Future<void> _confirmOrder(
      BuildContext context, WidgetRef ref, String? uid, String address) async {
    if (uid == null) return;

    if (!ref.read(emailVerifiedProvider)) {
      await ref.read(emailVerifiedProvider.notifier).refresh();
      if (!context.mounted) return;
    }

    final promo = ref.read(appliedPromoProvider(uid));
    String? promoCode;
    if (promo != null && promo.discountFor(subtotal) > 0) {
      promoCode = promo.code;
    }

    final orderIds = await ref.read(checkoutProvider.notifier).placeOrder(
          uid: uid,
          customerName:
              ref.read(sessionProfileProvider).valueOrNull?.name ?? '',
          lines: lines,
          address: address,
          emailVerified: ref.read(emailVerifiedProvider),
          promoCode: promoCode,
        );
    if (!context.mounted) return;
    if (orderIds == null) {
      final checkout = ref.read(checkoutProvider);
      if (checkout.pricesChanged) {
        ref.invalidate(cartLinesProvider(uid));
        ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
            checkout.error ?? 'Prices changed. Check your cart.',
            tone: SnackTone.error));
        Navigator.of(context).pop();
        return;
      }
      if (checkout.promoRejected) {
        ref.read(appliedPromoProvider(uid).notifier).state = null;
      }
      return;
    }
    ref.read(appliedPromoProvider(uid).notifier).state = null;
    HapticFeedback.mediumImpact();
    unawaited(askForPushPermission());

    final viewOrders = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _OrderPlacedSheet(orderCount: orderIds.length),
    );
    if (!context.mounted) return;
    var nextTab = CustomerTabs.home;
    if (viewOrders == true) nextTab = CustomerTabs.orders;
    ref.read(customerTabRequestProvider.notifier).state = nextTab;
    Navigator.of(context)
        .popUntil((route) => route.settings.name == '/home' || route.isFirst);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final address =
        ref.watch(sessionProfileProvider).valueOrNull?.address ?? '';
    final checkout = ref.watch(checkoutProvider);
    final error = checkout.error;
    final promo = uid == null ? null : ref.watch(appliedPromoProvider(uid));
    final discount = promo?.discountFor(subtotal) ?? 0;

    final farmerIds = <String>[];
    final itemsByFarmer = <String, List<CartLine>>{};
    for (final line in lines) {
      if (!itemsByFarmer.containsKey(line.farmerId)) {
        farmerIds.add(line.farmerId);
      }
      itemsByFarmer.putIfAbsent(line.farmerId, () => []).add(line);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F3),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const PageHeader(title: 'Checkout'),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                    children: [
                      const _SectionLabel('Your items'),
                      _Card(
                        child: Column(
                          children: [
                            for (var i = 0; i < lines.length; i++) ...[
                              if (i > 0)
                                const Divider(
                                    height: 20, color: Color(0xFFEEF1EA)),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lines[i].itemName,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: _textMain,
                                          ),
                                        ),
                                        Text(
                                          '${lines[i].quantity} × ${_rupees(lines[i].pricePerUnit)}',
                                          style: const TextStyle(
                                              fontSize: 12, color: _textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _rupees(lines[i].lineTotal),
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: _textMain),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      const _SectionLabel('Your address'),
                      _Card(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                  color: _tint,
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.home_outlined,
                                  size: 20, color: _brand),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    address.isEmpty
                                        ? 'No address on file'
                                        : address,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          address.isEmpty ? _danger : _textMain,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'You can change this from your profile.',
                                    style: TextStyle(
                                        fontSize: 12, color: _textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      const _SectionLabel('Pickup slot'),
                      for (var i = 0; i < farmerIds.length; i++) ...[
                        _PickupSlotPicker(
                          farmerId: farmerIds[i],
                          itemNames: [
                            for (final line in itemsByFarmer[farmerIds[i]]!)
                              line.itemName
                          ],
                          showItems: farmerIds.length > 1,
                          selected: checkout.slots[farmerIds[i]],
                          onSelected: (slot) {
                            ref.read(checkoutProvider.notifier).selectSlot(
                                  farmerIds[i],
                                  slot == null
                                      ? null
                                      : PickupSelection(
                                          slotId: slot.slotId,
                                          slotTime: slot.slotTime),
                                );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 10),
                      const _SectionLabel('Payment summary'),
                      _Card(
                        child: Column(
                          children: [
                            _SummaryRow(
                                label: 'Item total', value: _rupees(subtotal)),
                            if (discount > 0)
                              _SummaryRow(
                                label: 'Promo ${promo!.code}',
                                value: '− ${_rupees(discount)}',
                                highlight: true,
                              ),
                            const _SummaryRow(label: 'Pickup', value: 'Free'),
                            const Divider(height: 20, color: Color(0xFFEEF1EA)),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Total',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: _textMain),
                                  ),
                                ),
                                Text(
                                  _rupees(subtotal - discount),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _brand,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 16, color: _textMuted),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'No payment is taken in the app. This is a simulated order.',
                              style: TextStyle(fontSize: 12, color: _textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _ConfirmBar(
              total: subtotal - discount,
              saving: discount,
              placing: checkout.placing,
              error: error,
              onConfirm: () => _confirmOrder(context, ref, uid, address),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: _textMain),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _brandDark.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, 5))
        ],
      ),
      child: child,
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _SummaryRow(
      {required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final color = highlight ? _brand : _textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label, style: TextStyle(fontSize: 14, color: color))),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: highlight ? _brand : _textMain)),
        ],
      ),
    );
  }
}

class _PickupSlotPicker extends ConsumerStatefulWidget {
  final String farmerId;
  final List<String> itemNames;
  final bool showItems;
  final PickupSelection? selected;
  final ValueChanged<PickupSlotModel?> onSelected;

  const _PickupSlotPicker({
    required this.farmerId,
    required this.itemNames,
    required this.showItems,
    required this.selected,
    required this.onSelected,
  });

  @override
  ConsumerState<_PickupSlotPicker> createState() => _PickupSlotPickerState();
}

class _PickupSlotPickerState extends ConsumerState<_PickupSlotPicker> {
  DateTime? _day;

  static DateTime _dateOf(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  String _dayLabel(DateTime day) {
    final today = _dateOf(DateTime.now());
    if (day == today) return 'Today';
    if (day == today.add(const Duration(days: 1))) return 'Tomorrow';
    return _slotDay.format(day);
  }

  @override
  Widget build(BuildContext context) {
    final farmerId = widget.farmerId;
    final selected = widget.selected;
    final onSelected = widget.onSelected;
    final slotsAsync = ref.watch(availableSlotsProvider(farmerId));

    Widget body;
    if (slotsAsync.isLoading && !slotsAsync.hasValue) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
            child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    } else if (slotsAsync.hasError && !slotsAsync.hasValue) {
      body = Row(
        children: [
          const Expanded(
            child: Text('Could not load pickup times.',
                style: TextStyle(fontSize: 13, color: _textMuted)),
          ),
          TextButton(
            onPressed: () => ref.invalidate(availableSlotsProvider(farmerId)),
            child: const Text('Retry'),
          ),
        ],
      );
    } else {
      final slots = slotsAsync.valueOrNull ?? const <PickupSlotModel>[];
      if (slots.isEmpty) {
        body = const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.schedule_rounded, size: 18, color: _textMuted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'This farmer has no open slots yet. They will confirm a pickup time with you.',
                style: TextStyle(fontSize: 13, height: 1.4, color: _textMuted),
              ),
            ),
          ],
        );
      } else {
        final days = <DateTime>[];
        for (final slot in slots) {
          final day = _dateOf(slot.slotTime);
          if (!days.contains(day)) days.add(day);
        }
        var day = _day;
        if (day == null || !days.contains(day)) {
          final chosen = selected?.slotTime;
          day = chosen != null && days.contains(_dateOf(chosen))
              ? _dateOf(chosen)
              : days.first;
        }
        final activeDay = day;
        final daySlots =
            slots.where((slot) => _dateOf(slot.slotTime) == activeDay).toList();

        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => _DayChip(
                  label: _dayLabel(days[index]),
                  selected: days[index] == activeDay,
                  onTap: () => setState(() => _day = days[index]),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in daySlots)
                  _SlotPill(
                    slot: slot,
                    selected: selected?.slotId == slot.slotId,
                    onTap: () => onSelected(
                        selected?.slotId == slot.slotId ? null : slot),
                  ),
              ],
            ),
          ],
        );
      }
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showItems) ...[
            Text(
              'For ${widget.itemNames.join(', ')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _textMain),
            ),
            const SizedBox(height: 10),
          ],
          body,
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? _brand : _tint,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _textMain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotPill extends StatelessWidget {
  final PickupSlotModel slot;
  final bool selected;
  final VoidCallback onTap;

  const _SlotPill(
      {required this.slot, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    var spotsColor = _textMuted;
    if (slot.remaining <= 2) spotsColor = const Color(0xFF8A5A0B);
    if (selected) spotsColor = Colors.white70;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${_slotDay.format(slot.slotTime)} at ${_slotTime.format(slot.slotTime)}, ${slot.remaining} spots left',
      excludeSemantics: true,
      child: Material(
        color: selected ? _brand : _tint,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minWidth: 104, minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected ? _brand : const Color(0xFFDDE5D2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _slotTime.format(slot.slotTime),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : _textMain),
                ),
                Text(
                  '${slot.remaining} spot${slot.remaining == 1 ? '' : 's'} left',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: spotsColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  final double total;
  final double saving;
  final bool placing;
  final String? error;
  final VoidCallback onConfirm;

  const _ConfirmBar(
      {required this.total,
      this.saving = 0,
      required this.placing,
      required this.error,
      required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final message = error;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: _brandDark.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (message != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(message,
                          style: const TextStyle(fontSize: 13, color: _danger)),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total',
                              style:
                                  TextStyle(fontSize: 12, color: _textMuted)),
                          Text(
                            _rupees(total),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _brand,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          if (saving > 0)
                            Text(
                              'You save ${_rupees(saving)}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _brand),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton(
                            key: const ValueKey('checkout_confirm_button'),
                            onPressed: placing ? null : onConfirm,
                            style: FilledButton.styleFrom(
                              backgroundColor: _brand,
                              disabledBackgroundColor: placing ? _brand : null,
                              disabledForegroundColor:
                                  placing ? Colors.white : null,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: placing
                                  ? const Row(
                                      key: ValueKey('placing'),
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2),
                                        ),
                                        SizedBox(width: 10),
                                        Flexible(
                                          child: Text(
                                            'Placing order...',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      'Confirm order',
                                      key: ValueKey('confirm'),
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderPlacedSheet extends StatelessWidget {
  final int orderCount;

  const _OrderPlacedSheet({required this.orderCount});

  @override
  Widget build(BuildContext context) {
    var message = 'The farmer has been told and will confirm your pickup soon.';
    if (orderCount > 1) {
      message =
          'Your items came from $orderCount farmers, so we created $orderCount orders. '
          'Each farmer will confirm their pickup.';
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(
                    begin: MediaQuery.of(context).disableAnimations ? 1 : 0.6,
                    end: 1),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Color(0xFFE6EEDC)),
                  child: const Icon(Icons.check_rounded,
                      size: 48, color: _brand, semanticLabel: 'Success'),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Order placed',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: _textMain),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, height: 1.45, color: _textMuted),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton(
                key: const ValueKey('order_placed_view_orders'),
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('View my orders',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('order_placed_continue'),
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                  foregroundColor: _brand, minimumSize: const Size(48, 48)),
              child: const Text('Continue shopping',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

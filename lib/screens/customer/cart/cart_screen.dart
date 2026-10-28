import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/app_logger.dart';
import '../../../models/cart_item.dart';
import '../../../models/product_model.dart';
import '../../../models/promo_code_model.dart';
import '../../../providers/cart_providers.dart';
import '../../../providers/promo_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../providers/session_providers.dart';
import '../../../services/cart_service.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/promo_service.dart';
import '../../../widgets/async_error_view.dart';
import 'checkout_screen.dart';
import '../../../widgets/app_snackbar.dart';

const Color _brand = Color(0xFF3B6D11);
const Color _brandDark = Color(0xFF2E4A0F);
const Color _textMain = Color(0xFF22301A);
const Color _textMuted = Color(0xFF6B7A5E);
const Color _tint = Color(0xFFEFF3EA);
const Color _danger = Color(0xFFD64545);
const Color _pageBg = Color(0xFFF6F8F3);

const Map<String, String> _unitShort = {
  'kg': 'kg',
  'litre': 'L',
  'dozen': 'dz',
  'piece': 'pc'
};

double _subtotal(List<CartLine> lines) {
  var total = 0.0;
  for (final line in lines) {
    total += line.lineTotal;
  }
  return total;
}

String _rupees(double amount) => 'Rs. ${amount.toStringAsFixed(0)}';

String _pickupLabel(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  final daysAway = day.difference(today).inDays;
  final clock = DateFormat('h:mm\u00A0a').format(time);
  if (daysAway == 0) return 'Today, $clock';
  if (daysAway == 1) return 'Tomorrow, $clock';
  return '${DateFormat('EEE, d MMM').format(time)}, $clock';
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(appSnackBar(message, tone: SnackTone.error));
}

Future<void> _confirmClearCart(BuildContext context, CartService cartService,
    String uid, VoidCallback onCleared) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Clear cart?'),
      content: const Text('All items will be removed from your cart.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep items')),
        TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFD64545)),
            child: const Text('Clear cart')),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    await cartService.clearCart(uid);
    onCleared();
  } catch (e, stack) {
    AppLogger.error('Clear cart failed', e, stack);
    if (!context.mounted) return;
    _showError(context, 'Could not clear your cart. Try again.');
  }
}

class CartScreen extends ConsumerWidget {
  final VoidCallback? onBack;

  const CartScreen({super.key, this.onBack});

  Future<void> _runCartAction(BuildContext context,
      Future<void> Function() action, String failMessage) async {
    try {
      await action();
    } catch (e, stack) {
      AppLogger.error(failMessage, e, stack);
      if (context.mounted) _showError(context, failMessage);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) {
      return const Scaffold(
          body: Center(child: Text('Please log in to view your cart.')));
    }

    final cartService = ref.read(cartServiceProvider);
    final linesAsync = ref.watch(cartLinesProvider(uid));
    final itemCount = linesAsync.valueOrNull?.length ?? 0;
    final hasItems = itemCount > 0;

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
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE3E9DA))),
                ),
                padding:
                    EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
                  child: Row(
                    children: [
                      if (backAction != null)
                        Semantics(
                          button: true,
                          label: 'Back',
                          child: InkWell(
                            onTap: backAction,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                        color:
                                            _brandDark.withValues(alpha: 0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: const Icon(Icons.chevron_left_rounded,
                                    color: _textMain),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'My Cart',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: _brand),
                            ),
                            if (itemCount > 0)
                              Text(
                                '$itemCount item${itemCount == 1 ? '' : 's'}',
                                style: const TextStyle(
                                    fontSize: 13, color: _textMuted),
                              ),
                          ],
                        ),
                      ),
                      if (hasItems)
                        TextButton.icon(
                          key: const ValueKey('cart_clear_button'),
                          onPressed: () => _confirmClearCart(
                            context,
                            cartService,
                            uid,
                            () => ref
                                .read(appliedPromoProvider(uid).notifier)
                                .state = null,
                          ),
                          style: TextButton.styleFrom(
                              foregroundColor: _danger,
                              minimumSize: const Size(48, 48)),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Clear cart',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: linesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => AsyncErrorView(
                    message:
                        'Could not load your cart. Check your connection and try again.',
                    onRetry: () => ref.invalidate(cartLinesProvider(uid)),
                  ),
                  data: (items) {
                    if (items.isEmpty) return _EmptyCart(onBrowse: onBack);

                    final subtotal = _subtotal(items);
                    final hasUnavailable =
                        items.any((line) => !line.isAvailable);
                    final cartProductIds =
                        items.map((line) => line.productId).toSet();

                    final farmerIds = <String>{};
                    for (final line in items) {
                      if (line.isAvailable && line.farmerId.isNotEmpty) {
                        farmerIds.add(line.farmerId);
                      }
                    }
                    final farmerIdsKey = (farmerIds.toList()..sort()).join(',');

                    final promo = ref.watch(appliedPromoProvider(uid));
                    final discount = promo?.discountFor(subtotal) ?? 0;

                    return Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 600),
                              child: ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                children: [
                                  _PickupStrip(farmerIdsKey: farmerIdsKey),
                                  const SizedBox(height: 16),
                                  for (final line in items) ...[
                                    _CartItemTile(
                                      line: line,
                                      onIncrement: () => _runCartAction(
                                        context,
                                        () => cartService.updateQuantity(uid,
                                            line.productId, line.quantity + 1),
                                        'Could not update the quantity. Try again.',
                                      ),
                                      onDecrement: () => _runCartAction(
                                        context,
                                        () => cartService.updateQuantity(uid,
                                            line.productId, line.quantity - 1),
                                        'Could not update the quantity. Try again.',
                                      ),
                                      onRemove: () => _runCartAction(
                                        context,
                                        () => cartService.removeItem(
                                            uid, line.productId),
                                        'Could not remove this item. Try again.',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                    alignment: Alignment.topCenter,
                                    child: discount > 0
                                        ? _BillDetails(
                                            subtotal: subtotal,
                                            discount: discount)
                                        : const SizedBox(
                                            width: double.infinity),
                                  ),
                                  _Suggestions(
                                      uid: uid,
                                      farmerIdsKey: farmerIdsKey,
                                      excludeIds: cartProductIds),
                                ],
                              ),
                            ),
                          ),
                        ),
                        _SummaryPanel(
                          promo: _PromoCard(
                              uid: uid,
                              subtotal: subtotal,
                              promo: promo,
                              discount: discount),
                          subtotal: subtotal,
                          discount: discount,
                          hasUnavailable: hasUnavailable,
                          onCheckout: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => CheckoutScreen(
                                    lines: items, subtotal: subtotal)),
                          ),
                        ),
                      ],
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

class _EmptyCart extends StatelessWidget {
  final VoidCallback? onBrowse;

  const _EmptyCart({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
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
              child: const Icon(Icons.shopping_cart_outlined,
                  size: 44, color: _brand),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _textMain),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add fresh produce from local farms to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textMuted),
            ),
            if (onBrowse != null) ...[
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

class _PickupStrip extends ConsumerWidget {
  final String farmerIdsKey;

  const _PickupStrip({required this.farmerIdsKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? value;
    var prefix = 'Pickup time is chosen at checkout';
    if (farmerIdsKey.isNotEmpty) {
      final earliest = ref.watch(earliestPickupProvider(farmerIdsKey));
      if (earliest.isLoading) {
        prefix = 'Checking pickup times...';
      } else {
        final time = earliest.valueOrNull;
        if (time != null) {
          prefix = 'Earliest pickup ';
          value = _pickupLabel(time);
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: const Color(0xFFE6EEDC),
          borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, size: 18, color: _brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: prefix,
                style: const TextStyle(fontSize: 13, color: _textMuted),
                children: [
                  if (value != null)
                    TextSpan(
                        text: value,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, color: _brand)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  final ProductModel? product;
  final double size;

  const _ProductThumb({required this.product, required this.size});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: _tint,
      alignment: Alignment.center,
      child: Icon(Icons.eco, color: const Color(0xFF9CBB7F), size: size * 0.45),
    );
    final item = product;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: item != null && item.hasImage
            ? CachedNetworkImage(
                imageUrl:
                    CloudinaryService.optimizedUrl(item.imageUrl!, width: 200),
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: _tint),
                errorWidget: (context, url, error) => fallback,
              )
            : fallback,
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;
  final double radius;

  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.background,
    required this.foreground,
    this.radius = 17,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: SizedBox(
            width: 44,
            height: 48,
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: enabled ? background : const Color(0xFFE4E8DF),
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: Icon(icon,
                    size: 18,
                    color: enabled ? foreground : const Color(0xFFA3AC9A)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartLine line;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _CartItemTile({
    required this.line,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final removeButton = _RoundIconButton(
      icon: Icons.delete_outline,
      tooltip: 'Remove from cart',
      onTap: onRemove,
      background: const Color(0xFFFCE8E8),
      foreground: _danger,
      radius: 10,
    );

    if (!line.isAvailable) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
            color: const Color(0xFFFDF2E3),
            borderRadius: BorderRadius.circular(22)),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF8A6A1F)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: _textMain),
                  ),
                  const Text(
                    'No longer available',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8A6A1F)),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onRemove, child: const Text('Remove')),
          ],
        ),
      );
    }

    final product = line.product!;
    final atStockLimit = line.quantity >= product.stockQty;
    final unit = _unitShort[product.unit] ?? product.unit;

    String? warning;
    if (!product.inStock) {
      warning = 'Out of stock';
    } else if (line.quantity > product.stockQty) {
      warning = 'Only ${product.stockQty} left';
    }

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line.itemName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: _textMain),
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            text: _rupees(line.pricePerUnit),
            style: const TextStyle(fontWeight: FontWeight.w700, color: _brand),
            children: [
              TextSpan(
                  text: ' / $unit',
                  style: const TextStyle(
                      fontWeight: FontWeight.w400, color: _textMuted)),
            ],
          ),
          style: const TextStyle(fontSize: 13),
        ),
        if (warning != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(warning,
                style: const TextStyle(fontSize: 12, color: _danger)),
          ),
      ],
    );

    final stepper = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundIconButton(
          icon: Icons.remove,
          tooltip: 'Decrease quantity',
          onTap: onDecrement,
          background: _tint,
          foreground: _textMain,
        ),
        SizedBox(
          width: 24,
          child: Text(
            '${line.quantity}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: _textMain),
          ),
        ),
        _RoundIconButton(
          icon: Icons.add,
          tooltip:
              atStockLimit ? 'No more stock available' : 'Increase quantity',
          onTap: atStockLimit ? null : onIncrement,
          background: _brand,
          foreground: Colors.white,
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: _brandDark.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
          final singleRow = constraints.maxWidth >= 520 && textScale <= 1.3;

          if (singleRow) {
            return Row(
              children: [
                _ProductThumb(product: product, size: 52),
                const SizedBox(width: 12),
                Expanded(child: details),
                stepper,
                removeButton,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProductThumb(product: product, size: 52),
                  const SizedBox(width: 12),
                  Expanded(child: details),
                ],
              ),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [stepper, removeButton],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PromoCard extends ConsumerWidget {
  final String uid;
  final double subtotal;
  final PromoCodeModel? promo;
  final double discount;

  const _PromoCard(
      {required this.uid,
      required this.subtotal,
      required this.promo,
      required this.discount});

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PromoSheet(uid: uid, subtotal: subtotal),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applied = promo;
    String title;
    String subtitle;
    String actionLabel;
    VoidCallback onAction;

    if (applied != null) {
      title = '${applied.code} applied';
      if (discount > 0) {
        subtitle = 'You save ${_rupees(discount)} on this order';
      } else {
        final shortBy = (applied.minOrder - subtotal).ceil();
        subtitle = 'Add Rs. $shortBy more to use this code';
      }
      actionLabel = 'Remove';
      onAction =
          () => ref.read(appliedPromoProvider(uid).notifier).state = null;
    } else {
      title = 'Apply promo code';
      subtitle = 'Have a code? Enter it here';
      final codes = ref.watch(availablePromoOffersProvider(uid)).valueOrNull ??
          const <PromoCodeModel>[];
      var best = 0.0;
      for (final code in codes) {
        final saving = code.discountFor(subtotal);
        if (saving > best) best = saving;
      }
      if (best > 0) {
        subtitle = 'Save up to ${_rupees(best)} on this order';
      } else if (codes.isNotEmpty) {
        subtitle = 'Offers available on bigger orders';
      }
      actionLabel = 'Apply';
      onAction = () => _openSheet(context);
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: applied == null ? onAction : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: const Color(0xFFFDF2E3),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(
                  applied == null
                      ? Icons.local_offer_outlined
                      : Icons.check_circle_outline,
                  size: 20,
                  color: const Color(0xFF8A5A00),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _textMain),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style:
                            const TextStyle(fontSize: 12, color: _textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const ValueKey('cart_promo_action_button'),
                onPressed: onAction,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFE6EEDC),
                  foregroundColor: _brand,
                  minimumSize: const Size(64, 40),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(actionLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoSheet extends ConsumerStatefulWidget {
  final String uid;
  final double subtotal;

  const _PromoSheet({required this.uid, required this.subtotal});

  @override
  ConsumerState<_PromoSheet> createState() => _PromoSheetState();
}

class _PromoSheetState extends ConsumerState<_PromoSheet> {
  final _controller = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply([String? presetCode]) async {
    if (_checking) return;
    if (presetCode != null) _controller.text = presetCode;
    if (_controller.text.trim().isEmpty) {
      setState(() => _error = 'Enter a promo code.');
      return;
    }

    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final promo = await ref.read(promoServiceProvider).validateForCart(
            uid: widget.uid,
            rawCode: _controller.text,
            subtotal: widget.subtotal,
          );
      if (!mounted) return;
      ref.read(appliedPromoProvider(widget.uid).notifier).state = promo;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        appSnackBar(
            '${promo.code} applied. You save ${_rupees(promo.discountFor(widget.subtotal))}.',
            tone: SnackTone.success),
      );
    } on PromoCodeException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e, stack) {
      AppLogger.error('Promo validation failed', e, stack);
      if (mounted) {
        setState(() => _error =
            'Could not check this code. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final codesAsync = ref.watch(availablePromoOffersProvider(widget.uid));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xFFD5DBCD),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Apply promo code',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _textMain),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('cart_promo_field'),
                        controller: _controller,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 15,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp('[A-Za-z0-9]'))
                        ],
                        onSubmitted: (_) => _apply(),
                        decoration: InputDecoration(
                          labelText: 'Promo code',
                          counterText: '',
                          errorText: _error,
                          errorMaxLines: 2,
                          filled: true,
                          fillColor: _tint,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: _brand, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        key: const ValueKey('cart_promo_apply_button'),
                        onPressed: _checking ? null : () => _apply(),
                        style: FilledButton.styleFrom(
                          backgroundColor: _brand,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _checking
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: _brand, strokeWidth: 2),
                              )
                            : const Text('Apply'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'AVAILABLE OFFERS',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: _textMuted),
                ),
                const SizedBox(height: 8),
                codesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => Row(
                    children: [
                      const Expanded(
                        child: Text('Could not load offers.',
                            style: TextStyle(fontSize: 13, color: _textMuted)),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(activePromoCodesProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                  data: (codes) {
                    if (codes.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No offers right now.',
                            style: TextStyle(fontSize: 13, color: _textMuted)),
                      );
                    }
                    return Column(
                      children: [
                        for (final code in codes)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.local_offer_outlined,
                                color: Color(0xFF8A5A00)),
                            title: Text(code.code,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6)),
                            subtitle: Text(
                                '${code.shortLabel} · min order ${_rupees(code.minOrder)}'),
                            trailing: TextButton(
                              onPressed:
                                  _checking ? null : () => _apply(code.code),
                              child: const Text('Use'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Suggestions extends ConsumerStatefulWidget {
  final String uid;
  final String farmerIdsKey;
  final Set<String> excludeIds;

  const _Suggestions(
      {required this.uid,
      required this.farmerIdsKey,
      required this.excludeIds});

  @override
  ConsumerState<_Suggestions> createState() => _SuggestionsState();
}

class _SuggestionsState extends ConsumerState<_Suggestions> {
  final Set<String> _adding = {};

  Future<void> _add(ProductModel product) async {
    if (_adding.contains(product.productId)) return;
    setState(() => _adding.add(product.productId));
    try {
      await ref
          .read(cartServiceProvider)
          .addOrIncrement(userId: widget.uid, productId: product.productId);
      HapticFeedback.lightImpact();
    } catch (e, stack) {
      AppLogger.error('Add suggestion failed', e, stack);
      if (mounted) {
        _showError(context, 'Could not add ${product.itemName}. Try again.');
      }
    } finally {
      if (mounted) setState(() => _adding.remove(product.productId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.farmerIdsKey.isEmpty) return const SizedBox.shrink();

    final suggestionsAsync =
        ref.watch(cartSuggestionsProvider(widget.farmerIdsKey));
    final textScaler = MediaQuery.textScalerOf(context);
    final cardHeight = 84 +
        22 +
        textScaler.scale(13) * 1.3 * 2 +
        textScaler.scale(12) * 1.4 +
        8;

    Widget? body;
    if (suggestionsAsync.hasError && !suggestionsAsync.hasValue) {
      body = Row(
        children: [
          const Expanded(
            child: Text('Could not load suggestions.',
                style: TextStyle(fontSize: 13, color: _textMuted)),
          ),
          TextButton(
            onPressed: () {
              for (final farmerId in widget.farmerIdsKey.split(',')) {
                ref.invalidate(farmerShopProductsProvider(farmerId));
              }
            },
            child: const Text('Retry'),
          ),
        ],
      );
    } else if (suggestionsAsync.isLoading && !suggestionsAsync.hasValue) {
      body = SizedBox(
        height: cardHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => Container(
            width: 116,
            decoration: BoxDecoration(
                color: const Color(0xFFE9EEE3),
                borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
    } else {
      final products = <ProductModel>[];
      for (final product
          in suggestionsAsync.valueOrNull ?? const <ProductModel>[]) {
        if (!widget.excludeIds.contains(product.productId)) {
          products.add(product);
        }
        if (products.length == 8) break;
      }
      if (products.isEmpty) return const SizedBox.shrink();

      body = SizedBox(
        height: cardHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final product = products[index];
            return _SuggestionCard(
              product: product,
              busy: _adding.contains(product.productId),
              onAdd: () => _add(product),
            );
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add to your order',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: _textMain),
          ),
          const SizedBox(height: 10),
          body,
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final ProductModel product;
  final bool busy;
  final VoidCallback onAdd;

  const _SuggestionCard(
      {required this.product, required this.busy, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final unit = _unitShort[product.unit] ?? product.unit;

    final addButton = Tooltip(
      message: 'Add ${product.itemName}',
      child: Semantics(
        button: true,
        label: 'Add ${product.itemName} to cart',
        child: InkResponse(
          onTap: busy ? null : onAdd,
          radius: 24,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _brand,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(7),
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.add, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );

    return Container(
      width: 116,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _brandDark.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 84,
                  width: double.infinity,
                  child: product.hasImage
                      ? CachedNetworkImage(
                          imageUrl: CloudinaryService.optimizedUrl(
                              product.imageUrl!,
                              width: 240),
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: _tint),
                          errorWidget: (context, url, error) => Container(
                            color: _tint,
                            child:
                                const Icon(Icons.eco, color: Color(0xFF9CBB7F)),
                          ),
                        )
                      : Container(
                          color: _tint,
                          child:
                              const Icon(Icons.eco, color: Color(0xFF9CBB7F))),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.itemName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: _textMain),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_rupees(product.pricePerUnit)}/$unit',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _brand),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(top: 60, right: 2, child: addButton),
        ],
      ),
    );
  }
}

class _BillDetails extends StatelessWidget {
  final double subtotal;
  final double discount;

  const _BillDetails({required this.subtotal, required this.discount});

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value, {bool strong = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: strong ? 15 : 13,
                        fontWeight: strong ? FontWeight.w700 : null,
                        color: strong ? _textMain : _textMuted))),
            Text(value,
                style: TextStyle(
                    fontSize: strong ? 15 : 13,
                    fontWeight: FontWeight.w700,
                    color: strong ? _brand : _textMain)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: _brandDark.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Bill details',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _textMain)),
          const SizedBox(height: 6),
          row('Item total', _rupees(subtotal)),
          row('Coupon savings', '− ${_rupees(discount)}'),
          const Divider(height: 18),
          row('Total', _rupees(subtotal - discount), strong: true),
        ],
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  final Widget promo;
  final double subtotal;
  final double discount;
  final bool hasUnavailable;
  final VoidCallback onCheckout;

  const _SummaryPanel({
    required this.promo,
    required this.subtotal,
    required this.discount,
    required this.hasUnavailable,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: const Color(0xFFE3E9DA)),
        boxShadow: [
          BoxShadow(
              color: _brandDark.withValues(alpha: 0.12),
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  promo,
                  const Divider(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Total',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _textMain)),
                      ),
                      Text(
                        _rupees(subtotal - discount),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _brand,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  if (hasUnavailable)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Remove the unavailable items to continue to checkout.',
                        style: TextStyle(fontSize: 12, color: _danger),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: hasUnavailable
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF5A9A1F), _brandDark]),
                        color: hasUnavailable ? const Color(0xFFD9DED3) : null,
                      ),
                      child: TextButton(
                        key: const ValueKey('cart_checkout_button'),
                        onPressed: hasUnavailable ? null : onCheckout,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          disabledForegroundColor: const Color(0xFF6B7A5E),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                'Proceed to checkout',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.eco, size: 18),
                          ],
                        ),
                      ),
                    ),
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

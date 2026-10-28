import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_logger.dart';
import '../../../core/constants.dart';
import '../../../models/product_model.dart';
import '../../../providers/service_providers.dart';
import '../../../providers/session_providers.dart';
import '../../../providers/wishlist_providers.dart';
import '../../../services/cloudinary_service.dart';
import '../../../widgets/async_error_view.dart';
import '../home/product_details_screen.dart';
import '../../../widgets/app_snackbar.dart';

const Color _brand = Color(0xFF3B6D11);
const Color _brandDark = Color(0xFF2E4A0F);
const Color _textMain = Color(0xFF22301A);
const Color _textMuted = Color(0xFF6B7A5E);
const Color _tint = Color(0xFFEFF3EA);
const Color _pageBg = Color(0xFFF6F8F3);
const Color _heart = Color(0xFFD64545);

const Duration _freshWindow = Duration(days: 7);

class WishlistScreen extends ConsumerWidget {
  final VoidCallback? onBack;

  const WishlistScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);

    if (uid == null) {
      return const Scaffold(
          body: Center(child: Text('Please log in to view your wishlist.')));
    }

    final entriesAsync = ref.watch(wishlistEntriesProvider(uid));
    final count = entriesAsync.valueOrNull?.length ?? 0;

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
                padding: EdgeInsets.fromLTRB(
                    12, MediaQuery.paddingOf(context).top + 8, 16, 10),
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
                                      color: _brandDark.withValues(alpha: 0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.chevron_left_rounded,
                                    color: _textMain),
                              ),
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
                            'Wishlist',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: _brand),
                          ),
                          Text(
                            count == 0
                                ? 'Products you save appear here'
                                : '$count saved item${count == 1 ? '' : 's'}',
                            style: const TextStyle(
                                fontSize: 13, color: _textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: entriesAsync.when(
                  skipLoadingOnReload: true,
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => AsyncErrorView(
                    message:
                        'Could not load your wishlist. Check your connection and try again.',
                    onRetry: () => ref.invalidate(wishlistIdsProvider(uid)),
                  ),
                  data: (entries) {
                    if (entries.isEmpty) {
                      return _EmptyWishlist(onBrowse: onBack);
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        const spacing = 12.0;
                        final contentWidth = constraints.maxWidth - 32;
                        var cardWidth = contentWidth;
                        if (contentWidth >= 700) {
                          cardWidth = (contentWidth - spacing) / 2;
                        }

                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          child: Column(
                            children: [
                              Wrap(
                                spacing: spacing,
                                runSpacing: spacing,
                                children: [
                                  for (final entry in entries)
                                    SizedBox(
                                      width: cardWidth,
                                      child: entry.product == null
                                          ? _UnavailableCard(
                                              uid: uid,
                                              productId: entry.productId)
                                          : _WishlistCard(
                                              uid: uid,
                                              entry: entry,
                                              product: entry.product!),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
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

class _EmptyWishlist extends StatelessWidget {
  final VoidCallback? onBrowse;

  const _EmptyWishlist({required this.onBrowse});

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
              child: const Icon(Icons.favorite_border, size: 44, color: _brand),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your wishlist is empty',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _textMain),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap the heart on any product to save it for later.',
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

class _WishlistCard extends ConsumerStatefulWidget {
  final String uid;
  final WishlistEntry entry;
  final ProductModel product;

  const _WishlistCard(
      {required this.uid, required this.entry, required this.product});

  @override
  ConsumerState<_WishlistCard> createState() => _WishlistCardState();
}

class _WishlistCardState extends ConsumerState<_WishlistCard> {
  bool _adding = false;
  bool _removing = false;

  Future<void> _addToCart() async {
    if (_adding) return;
    setState(() => _adding = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(cartServiceProvider).addOrIncrement(
            userId: widget.uid,
            productId: widget.product.productId,
          );
      HapticFeedback.lightImpact();
      messenger.showSnackBar(appSnackBar(
          '${widget.product.itemName} added to cart.',
          tone: SnackTone.success));
    } catch (e, stack) {
      AppLogger.error('Wishlist add to cart failed', e, stack);
      messenger.showSnackBar(
        appSnackBar(
            'Could not add ${widget.product.itemName} to cart. Try again.',
            tone: SnackTone.error),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _remove() async {
    if (_removing) return;
    setState(() => _removing = true);
    final messenger = ScaffoldMessenger.of(context);
    final wishlistService = ref.read(wishlistServiceProvider);
    final uid = widget.uid;
    final productId = widget.product.productId;
    final name = widget.product.itemName;
    try {
      await wishlistService.remove(uid, productId);
      messenger.showSnackBar(
        appSnackBar('$name removed from wishlist.',
            tone: SnackTone.success,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                try {
                  await wishlistService.add(uid, productId);
                } catch (e, stack) {
                  AppLogger.error('Wishlist undo failed', e, stack);
                  messenger.showSnackBar(appSnackBar('Could not restore $name.',
                      tone: SnackTone.error));
                }
              },
            )),
      );
    } catch (e, stack) {
      AppLogger.error('Wishlist remove failed', e, stack);
      messenger.showSnackBar(appSnackBar('Could not remove $name. Try again.',
          tone: SnackTone.error));
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isFresh =
        DateTime.now().difference(product.createdAt) <= _freshWindow;
    final canOrder = product.canBeOrdered;

    final details = <String>[];
    final category = widget.entry.categoryName;
    final farm = widget.entry.farmName;
    if (category != null && category.isNotEmpty) details.add(category);
    if (farm != null && farm.isNotEmpty) details.add(farm);

    String? stockLabel;
    IconData stockIcon = Icons.warning_amber_rounded;
    Color stockColor = const Color(0xFF8A6A1F);
    if (!product.isAvailable) {
      stockLabel = 'Unavailable';
      stockIcon = Icons.block;
    } else if (!product.inStock) {
      stockLabel = 'Out of stock';
      stockIcon = Icons.remove_shopping_cart_outlined;
      stockColor = const Color(0xFFB3261E);
    } else if (product.stockQty <= StockRules.lowStockThreshold) {
      stockLabel = 'Only ${product.stockQty} left';
    }
    final stock = stockLabel;

    final unit = product.unit;
    final removeButton = Tooltip(
      message: 'Remove from wishlist',
      child: Semantics(
        button: true,
        label: 'Remove ${product.itemName} from wishlist',
        child: InkResponse(
          onTap: _removing ? null : _remove,
          radius: 22,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: _removing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _heart),
                    )
                  : const Icon(Icons.favorite, size: 22, color: _heart),
            ),
          ),
        ),
      ),
    );

    final addButton = SizedBox(
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: canOrder
              ? const LinearGradient(colors: [Color(0xFF5A9A1F), _brandDark])
              : null,
          color: canOrder ? null : const Color(0xFFE4E8DF),
        ),
        child: TextButton.icon(
          key: ValueKey('wishlist_add_${product.productId}'),
          onPressed: canOrder && !_adding ? _addToCart : null,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            disabledForegroundColor:
                _adding ? Colors.white : const Color(0xFF6B7A5E),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: const Size(48, 40),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _adding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.add_shopping_cart_outlined, size: 18),
          label: const Text('Add',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ),
    );

    return Container(
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) =>
                    ProductDetailsScreen(productId: product.productId)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: product.hasImage
                        ? CachedNetworkImage(
                            imageUrl: CloudinaryService.optimizedUrl(
                                product.imageUrl!,
                                width: 240),
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: _tint),
                            errorWidget: (context, url, error) =>
                                const _ImageFallback(),
                          )
                        : const _ImageFallback(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                product.itemName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: _textMain),
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(0, -8),
                            child: removeButton,
                          ),
                        ],
                      ),
                      if (details.isNotEmpty)
                        Text(
                          details.join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontSize: 12, color: _textMuted),
                        ),
                      if (stock != null || isFresh) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 10,
                          runSpacing: 2,
                          children: [
                            if (stock != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(stockIcon, size: 14, color: stockColor),
                                  const SizedBox(width: 4),
                                  Text(stock,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: stockColor)),
                                ],
                              ),
                            if (isFresh)
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.eco, size: 14, color: _brand),
                                  SizedBox(width: 4),
                                  Text('Fresh pick',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _brand)),
                                ],
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text.rich(
                                  TextSpan(
                                    text:
                                        'Rs. ${product.pricePerUnit.toStringAsFixed(0)}',
                                    children: [
                                      TextSpan(
                                        text: '/$unit',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _textMuted),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: _brand,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            addButton,
                          ],
                        ),
                      ),
                    ],
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

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F4EC), Color(0xFFE3E9DA)],
        ),
      ),
      child: const Center(
          child: Icon(Icons.eco, size: 48, color: Color(0xFF9CBB7F))),
    );
  }
}

class _UnavailableCard extends ConsumerWidget {
  final String uid;
  final String productId;

  const _UnavailableCard({required this.uid, required this.productId});

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(wishlistServiceProvider).remove(uid, productId);
    } catch (e, stack) {
      AppLogger.error('Wishlist remove failed', e, stack);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar('Could not remove this item. Try again.',
            tone: SnackTone.error),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
          color: const Color(0xFFFDF2E3),
          borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF8A6A1F)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'This product is no longer available',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Color(0xFF8A6A1F)),
            ),
          ),
          TextButton(
              onPressed: () => _remove(context, ref),
              child: const Text('Remove')),
        ],
      ),
    );
  }
}

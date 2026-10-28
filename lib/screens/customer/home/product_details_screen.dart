import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../widgets/product_card.dart';
import '../../../models/farmer_model.dart';
import '../../../models/market_model.dart';
import '../../../models/product_model.dart';
import '../../../providers/navigation_providers.dart';
import '../../../providers/product_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../providers/session_providers.dart';
import '../../../services/cloudinary_service.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/async_error_view.dart';
import '../../../widgets/page_header.dart';
import '../../../services/push_permission.dart';

const Color _brand = Color(0xFF3B6D11);
const Color _brandDark = Color(0xFF2E4A0F);
const Color _textMain = Color(0xFF22301A);
const Color _textBody = Color(0xFF4C5943);
const Color _textMuted = Color(0xFF6B7A5E);
const Color _tint = Color(0xFFEFF3EA);
const Color _pageBg = Color(0xFFF6F8F3);
const Color _border = Color(0xFFE3E9DA);
const Color _lowStock = Color(0xFF8A5A00);
const Color _outOfStock = Color(0xFFB3261E);
const Color _heart = Color(0xFFD64545);

const int _maxQuantity = 99;

class ProductDetailsScreen extends ConsumerStatefulWidget {
  final String productId;
  const ProductDetailsScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  int _quantity = 1;
  bool _followBusy = false;
  bool _collapsed = false;

  bool _onScroll(ScrollNotification notification, double collapseAt) {
    if (notification.depth != 0) return false;
    final collapsed = notification.metrics.pixels > collapseAt;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    return false;
  }

  int _maxFor(ProductModel product) {
    if (product.stockQty < _maxQuantity) return product.stockQty;
    return _maxQuantity;
  }

  void _changeQuantity(ProductModel product, int delta) {
    final next = _quantity + delta;
    if (next < 1 || next > _maxFor(product)) return;
    HapticFeedback.selectionClick();
    setState(() => _quantity = next);
  }

  void _openCart() {
    ref.read(customerTabRequestProvider.notifier).state = CustomerTabs.cart;
    Navigator.of(context)
        .popUntil((route) => route.settings.name == '/home' || route.isFirst);
  }

  Future<void> _addToCart(String uid, ProductModel product) async {
    final quantity = _quantity;
    final added = await ref
        .read(addToCartProvider.notifier)
        .add(uid: uid, productId: product.productId, quantity: quantity);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (!added) {
      messenger.showSnackBar(appSnackBar('Could not add to cart. Try again.',
          tone: SnackTone.error));
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _quantity = 1);
    messenger.showSnackBar(appSnackBar(
      'Added $quantity ${product.unit} of ${product.itemName} to your cart',
      tone: SnackTone.success,
      action: SnackBarAction(label: 'View cart', onPressed: _openCart),
    ));
  }

  Future<void> _toggleWishlist(
      String uid, ProductModel product, bool isWishlisted) async {
    final wishlistService = ref.read(wishlistServiceProvider);
    HapticFeedback.selectionClick();
    try {
      if (isWishlisted) {
        await wishlistService.remove(uid, product.productId);
      } else {
        await wishlistService.add(uid, product.productId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
        isWishlisted ? 'Removed from wishlist' : 'Saved to your wishlist',
        tone: SnackTone.success,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
          'Could not update wishlist. Try again.',
          tone: SnackTone.error));
    }
  }

  Future<void> _toggleFollow(String uid, FarmerModel farmer) async {
    if (_followBusy) return;
    setState(() => _followBusy = true);
    try {
      final wasFollowing = ref
              .read(isFollowingProvider((uid: uid, farmerId: farmer.farmerId)))
              .valueOrNull ??
          false;
      await ref.read(followServiceProvider).toggleFollow(uid, farmer.farmerId);
      HapticFeedback.selectionClick();
      if (!wasFollowing) await askForPushPermission();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
            'Could not update follow. Try again.',
            tone: SnackTone.error));
      }
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(productDetailProvider(widget.productId));
    final uid = ref.watch(currentUidProvider);

    if (detailAsync.hasError && !detailAsync.hasValue) {
      return Scaffold(
        backgroundColor: _pageBg,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              const PageHeader(title: 'Product'),
              Expanded(
                child: AsyncErrorView(
                  title: 'This item did not load',
                  message: 'Check your connection and try again.',
                  onRetry: () =>
                      ref.invalidate(productDetailProvider(widget.productId)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final detail = detailAsync.valueOrNull;
    if (detail == null) return const _DetailsSkeleton();

    final product = detail.product;
    if (product == null) {
      return Scaffold(
        backgroundColor: _pageBg,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              const PageHeader(title: 'Product'),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                          radius: 32,
                          backgroundColor: _tint,
                          child:
                              Icon(Icons.eco_outlined, color: _brand, size: 30),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'This item is no longer available',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _textMain),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'The farmer may have removed it. Have a look at other fresh picks.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14, height: 1.4, color: _textMuted),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: _brand,
                            minimumSize: const Size(160, 48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Back to shop'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final farmer = detail.farmer;
    final canOrder = product.canBeOrdered;
    final maxQuantity = _maxFor(product);
    final size = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final collapseAt = _Hero.heightFor(size) - topInset - 72;

    final overlayStyle =
        _collapsed ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) =>
                  _onScroll(notification, collapseAt),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _Hero(
                      product: product,
                      wishlistButton: uid == null
                          ? null
                          : _WishlistButton(
                              uid: uid,
                              productId: product.productId,
                              onToggle: (isWishlisted) =>
                                  _toggleWishlist(uid, product, isWishlisted),
                            ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -24),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(28)),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (detail.categoryName.isNotEmpty)
                                        _Pill(
                                          label: detail.categoryName,
                                          color: _brand,
                                          background: _tint,
                                        ),
                                      _stockPill(product),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    product.itemName,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      height: 1.2,
                                      fontWeight: FontWeight.w800,
                                      color: _textMain,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _PriceRow(product: product),
                                  if (canOrder) ...[
                                    const SizedBox(height: 20),
                                    _QuantityRow(
                                      quantity: _quantity,
                                      max: maxQuantity,
                                      unit: product.unit,
                                      onChanged: (delta) =>
                                          _changeQuantity(product, delta),
                                    ),
                                  ],
                                  if (product.description
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 24),
                                    const _SectionTitle('About this product'),
                                    const SizedBox(height: 8),
                                    Text(
                                      product.description.trim(),
                                      style: const TextStyle(
                                          fontSize: 15,
                                          height: 1.5,
                                          color: _textBody),
                                    ),
                                  ],
                                  if (farmer != null) ...[
                                    const SizedBox(height: 24),
                                    const _SectionTitle('Sold by'),
                                    const SizedBox(height: 10),
                                    _FarmerCard(
                                      farmer: farmer,
                                      market: detail.market,
                                      followButton: uid == null
                                          ? null
                                          : _FollowButton(
                                              uid: uid,
                                              farmerId: farmer.farmerId,
                                              busy: _followBusy,
                                              onTap: () =>
                                                  _toggleFollow(uid, farmer),
                                            ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                ignoring: !_collapsed,
                child: AnimatedOpacity(
                  opacity: _collapsed ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: _CollapsedBar(title: product.itemName),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _BottomBar(
          product: product,
          quantity: _quantity,
          enabled: uid != null,
          onAdd: uid == null ? null : () => _addToCart(uid, product),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final ProductModel product;
  final Widget? wishlistButton;

  const _Hero({required this.product, this.wishlistButton});

  static double heightFor(Size size) {
    final height = size.width / 1.05;
    if (height > size.height * 0.48) return size.height * 0.48;
    return height;
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final height = heightFor(MediaQuery.sizeOf(context));

    Widget image = product.hasImage
        ? CachedNetworkImage(
            imageUrl:
                CloudinaryService.optimizedUrl(product.imageUrl!, width: 1080),
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 200),
            placeholder: (context, url) => Container(color: _tint),
            errorWidget: (context, url, error) => const _HeroPlaceholder(),
          )
        : const _HeroPlaceholder();
    if (!product.inStock) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix(greyscaleMatrix),
        child: image,
      );
    }

    final wishlist = wishlistButton;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            image: true,
            label: '${product.itemName} photo',
            child: image,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment(0, -0.2),
                colors: [Color(0x66000000), Color(0x00000000)],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: topInset + 8,
            child: Row(
              children: [
                _CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                if (wishlist != null) wishlist,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedBar extends StatelessWidget {
  final String title;

  const _CollapsedBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: _brandDark.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded, color: _textMain),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _textMain),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9EFE1), Color(0xFFD5E0C8)],
        ),
      ),
      child: Center(
        child: Icon(Icons.eco_rounded, size: 72, color: Color(0xFF9CBB7F)),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = _textMain,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: Colors.white.withValues(alpha: 0.94),
          shape: const CircleBorder(),
          elevation: 2,
          shadowColor: _brandDark.withValues(alpha: 0.3),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(icon, size: 22, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _WishlistButton extends ConsumerWidget {
  final String uid;
  final String productId;
  final ValueChanged<bool> onToggle;

  const _WishlistButton(
      {required this.uid, required this.productId, required this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWishlisted = ref
            .watch(isWishlistedProvider((uid: uid, productId: productId)))
            .valueOrNull ??
        false;
    return _CircleIconButton(
      icon:
          isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      color: isWishlisted ? _heart : _textMain,
      tooltip: isWishlisted ? 'Remove from wishlist' : 'Add to wishlist',
      onTap: () => onToggle(isWishlisted),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  const _Pill({
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final pillIcon = icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pillIcon != null) ...[
            Icon(pillIcon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _stockPill(ProductModel product) {
  var stockLabel = '${product.stockQty} ${product.unit} in stock';
  var stockColor = _brand;
  var stockBackground = _tint;
  var stockIcon = Icons.check_circle_outline_rounded;
  if (!product.inStock) {
    stockLabel = 'Out of stock';
    stockColor = _outOfStock;
    stockBackground = const Color(0xFFFBE9E7);
    stockIcon = Icons.block_rounded;
  } else if (product.stockQty <= StockRules.lowStockThreshold) {
    stockLabel = 'Only ${product.stockQty} left';
    stockColor = _lowStock;
    stockBackground = const Color(0xFFFDF2E3);
    stockIcon = Icons.local_fire_department_outlined;
  } else if (!product.isAvailable) {
    stockLabel = 'Not available now';
    stockColor = _textMuted;
    stockBackground = const Color(0xFFEDEFEA);
    stockIcon = Icons.pause_circle_outline_rounded;
  }

  return _Pill(
    label: stockLabel,
    color: stockColor,
    background: stockBackground,
    icon: stockIcon,
  );
}

class _PriceRow extends StatelessWidget {
  final ProductModel product;

  const _PriceRow({required this.product});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: 'Rs. ${product.pricePerUnit.toStringAsFixed(0)}',
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: _brand,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        children: [
          TextSpan(
            text: '  per ${product.unit}',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: _textMuted),
          ),
        ],
      ),
    );
  }
}

class _QuantityRow extends StatelessWidget {
  final int quantity;
  final int max;
  final String unit;
  final ValueChanged<int> onChanged;

  const _QuantityRow({
    required this.quantity,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: _pageBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quantity',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _textMain)),
                const SizedBox(height: 2),
                Text('In $unit · up to $max',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _textMuted)),
              ],
            ),
          ),
          _StepButton(
            icon: Icons.remove_rounded,
            tooltip: 'Decrease quantity',
            onTap: quantity > 1 ? () => onChanged(-1) : null,
          ),
          SizedBox(
            width: 44,
            child: Semantics(
              liveRegion: true,
              label: 'Quantity $quantity',
              child: ExcludeSemantics(
                child: Text(
                  '$quantity',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _textMain,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            tooltip: 'Increase quantity',
            filled: true,
            onTap: quantity < max ? () => onChanged(1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool filled;

  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    var background = Colors.white;
    var foreground = _textMain;
    if (filled) {
      background = _brand;
      foreground = Colors.white;
    }
    if (!enabled) {
      background = const Color(0xFFE6EBDF);
      foreground = const Color(0xFFA3AC9A);
    }

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
            width: 48,
            height: 48,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      filled || !enabled ? null : Border.all(color: _border),
                ),
                child: Icon(icon, size: 20, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800, color: _textMain),
      ),
    );
  }
}

class _FarmerCard extends StatelessWidget {
  final FarmerModel farmer;
  final MarketModel? market;
  final Widget? followButton;

  const _FarmerCard(
      {required this.farmer, required this.market, this.followButton});

  @override
  Widget build(BuildContext context) {
    final imageUrl = farmer.imageUrl;
    final follow = followButton;
    final place = market;

    var ratingText = 'New on HarvestHub';
    if (farmer.ratingCount > 0) {
      final noun = farmer.ratingCount == 1 ? 'rating' : 'ratings';
      ratingText =
          '${farmer.rating.toStringAsFixed(1)}  (${farmer.ratingCount} $noun)';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _pageBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                ),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: CloudinaryService.optimizedUrl(imageUrl,
                            width: 160),
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const Icon(
                            Icons.agriculture_rounded,
                            color: _brand),
                      )
                    : const Icon(Icons.agriculture_rounded, color: _brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            farmer.businessName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _textMain),
                          ),
                        ),
                        if (farmer.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              size: 16,
                              color: _brand,
                              semanticLabel: 'Verified farmer'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          farmer.ratingCount > 0
                              ? Icons.star_rounded
                              : Icons.eco_outlined,
                          size: 15,
                          color: farmer.ratingCount > 0
                              ? const Color(0xFFEF9F27)
                              : _textMuted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            ratingText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: _textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (follow != null) ...[
                const SizedBox(width: 8),
                follow,
              ],
            ],
          ),
          if (farmer.description.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              farmer.description.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 14, height: 1.45, color: _textBody),
            ),
          ],
          if (place != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: _border),
            const SizedBox(height: 12),
            _InfoLine(
              icon: Icons.place_outlined,
              title: place.marketName,
              subtitle: place.address,
            ),
            if (place.operatingHours.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              _InfoLine(
                icon: Icons.schedule_rounded,
                title: 'Pickup hours',
                subtitle: place.operatingHours,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoLine(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: _brand),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textMain)),
              if (subtitle.trim().isNotEmpty)
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 13, height: 1.4, color: _textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _FollowButton extends ConsumerWidget {
  final String uid;
  final String farmerId;
  final bool busy;
  final VoidCallback onTap;

  const _FollowButton({
    required this.uid,
    required this.farmerId,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFollowing = ref
            .watch(isFollowingProvider((uid: uid, farmerId: farmerId)))
            .valueOrNull ??
        false;

    final child = busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: _brand),
          )
        : Text(isFollowing ? 'Following' : 'Follow');

    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    if (isFollowing) {
      return OutlinedButton(
        key: const ValueKey('product_follow_button'),
        onPressed: busy ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: _brand,
          minimumSize: const Size(96, 44),
          side: const BorderSide(color: _border),
          backgroundColor: Colors.white,
          shape: shape,
        ),
        child: child,
      );
    }
    return FilledButton(
      key: const ValueKey('product_follow_button'),
      onPressed: busy ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: _brand,
        minimumSize: const Size(96, 44),
        shape: shape,
      ),
      child: child,
    );
  }
}

class _BottomBar extends ConsumerWidget {
  final ProductModel product;
  final int quantity;
  final bool enabled;
  final VoidCallback? onAdd;

  const _BottomBar({
    required this.product,
    required this.quantity,
    required this.enabled,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adding = ref.watch(addToCartProvider);
    final canOrder = product.canBeOrdered;
    final total = product.pricePerUnit * quantity;
    final action = onAdd;

    var label = 'Add to cart';
    if (!product.inStock) {
      label = 'Out of stock';
    } else if (!product.isAvailable) {
      label = 'Not available';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: _brandDark.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  if (canOrder) ...[
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total',
                            style: TextStyle(fontSize: 12, color: _textMuted)),
                        Text(
                          'Rs. ${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _textMain,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        key: const ValueKey('product_add_to_cart_button'),
                        onPressed:
                            canOrder && enabled && !adding && action != null
                                ? action
                                : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: _brand,
                          disabledBackgroundColor:
                              adding ? _brand : const Color(0xFFDDE3D5),
                          disabledForegroundColor:
                              adding ? Colors.white : const Color(0xFF7D8874),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: adding
                              ? const SizedBox(
                                  key: ValueKey('adding'),
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(
                                  canOrder
                                      ? Icons.add_shopping_cart_rounded
                                      : Icons.remove_shopping_cart_outlined,
                                  key: const ValueKey('idle')),
                        ),
                        label: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            adding ? 'Adding...' : label,
                            key: ValueKey(adding),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
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

class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    Widget bar(double barWidth, double height) => Container(
          width: barWidth,
          height: height,
          decoration: BoxDecoration(
              color: const Color(0xFFE9EEE3),
              borderRadius: BorderRadius.circular(8)),
        );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Semantics(
        label: 'Loading product',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: width / 1.05 > 420 ? 420 : width / 1.05,
              color: const Color(0xFFE9EEE3),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(90, 22),
                  const SizedBox(height: 14),
                  bar(width * 0.6, 28),
                  const SizedBox(height: 14),
                  bar(width * 0.4, 32),
                  const SizedBox(height: 24),
                  bar(double.infinity, 64),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

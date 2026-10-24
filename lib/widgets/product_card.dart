import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import '../services/cloudinary_service.dart';

const Color _brand = Color(0xFF3B6D11);
const Color _brandDark = Color(0xFF2E4A0F);
const Color _textMain = Color(0xFF22301A);
const Color _textMuted = Color(0xFF6B7A5E);
const Color _tint = Color(0xFFEFF3EA);
const Color _lowStock = Color(0xFF8A5A00);
const Color _outOfStock = Color(0xFFB3261E);

const Map<String, String> _unitShort = {
  'kg': 'kg',
  'litre': 'L',
  'dozen': 'dozen',
  'piece': 'pc'
};

const List<double> greyscaleMatrix = [
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

class ProductCard extends StatelessWidget {
  static const double imageAspectRatio = 1.2;
  static const double compactImageAspectRatio = 1.45;

  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback? onAdd;
  final bool adding;
  final String? farmerName;
  final String? categoryName;
  final bool compact;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onAdd,
    this.adding = false,
    this.farmerName,
    this.categoryName,
    this.compact = false,
  });

  static double heightFor(double cardWidth, TextScaler textScaler,
      {bool compact = false}) {
    if (compact) {
      final name = textScaler.scale(14) * 1.25;
      final farmer = textScaler.scale(12) * 1.3;
      final priceRow = textScaler.scale(16) * 1.25;
      final bottomRow = priceRow > 44 ? priceRow : 44;
      return cardWidth / compactImageAspectRatio +
          8 +
          name +
          2 +
          farmer +
          6 +
          bottomRow +
          8;
    }
    final imageHeight = cardWidth / imageAspectRatio;
    final caption = textScaler.scale(11) * 1.3;
    final name = textScaler.scale(15) * 1.25 * 2;
    final farmer = textScaler.scale(12) * 1.3;
    final priceRow = textScaler.scale(17) * 1.25 + textScaler.scale(12) * 1.3;
    final bottomRow = priceRow > 44 ? priceRow : 44;
    return imageHeight +
        12 +
        caption +
        4 +
        name +
        6 +
        farmer +
        10 +
        bottomRow +
        10;
  }

  @override
  Widget build(BuildContext context) {
    final canOrder = product.canBeOrdered;
    final unit = _unitShort[product.unit] ?? product.unit;

    var showStock = !compact;
    var stockLabel = '${product.stockQty} $unit left';
    var stockColor = _textMuted;
    var stockIcon = Icons.inventory_2_outlined;
    if (!product.inStock) {
      showStock = true;
      stockLabel = 'Out of stock';
      stockColor = _outOfStock;
      stockIcon = Icons.block_rounded;
    } else if (product.stockQty <= StockRules.lowStockThreshold) {
      showStock = true;
      stockLabel = 'Only ${product.stockQty} left';
      stockColor = _lowStock;
      stockIcon = Icons.local_fire_department_outlined;
    }

    final farmer = farmerName?.trim() ?? '';
    final category = categoryName?.trim() ?? '';
    final price = 'Rs. ${product.pricePerUnit.toStringAsFixed(0)}';

    Widget image = product.hasImage
        ? CachedNetworkImage(
            imageUrl:
                CloudinaryService.optimizedUrl(product.imageUrl!, width: 480),
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 200),
            placeholder: (context, url) => Container(color: _tint),
            errorWidget: (context, url, error) => const _ImagePlaceholder(),
          )
        : const _ImagePlaceholder();
    if (!product.inStock) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix(greyscaleMatrix),
        child: Opacity(opacity: 0.75, child: image),
      );
    }

    final addAction = onAdd;
    var semanticsLabel = '${product.itemName}, $price per ${product.unit}';
    if (farmer.isNotEmpty) semanticsLabel += ', from $farmer';
    semanticsLabel += ', $stockLabel';

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8EDE1)),
          boxShadow: [
            BoxShadow(
                color: _brandDark.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio:
                      compact ? compactImageAspectRatio : imageAspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      image,
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0x22000000)],
                          ),
                        ),
                      ),
                      if (showStock)
                        Positioned(
                          left: 8,
                          bottom: 8,
                          right: 8,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ExcludeSemantics(
                              child: _StockPill(
                                label: stockLabel,
                                color: stockColor,
                                icon: stockIcon,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: compact
                        ? const EdgeInsets.fromLTRB(10, 8, 4, 8)
                        : const EdgeInsets.fromLTRB(12, 12, 8, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!compact) ...[
                                Text(
                                  category.isEmpty
                                      ? ' '
                                      : category.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.3,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: Color(0xFF3B6D11),
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              Text(
                                product.itemName,
                                maxLines: compact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: compact ? 14 : 15,
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                  color: _textMain,
                                ),
                              ),
                              SizedBox(height: compact ? 2 : 6),
                              Row(
                                children: [
                                  if (!compact) ...[
                                    const Icon(Icons.storefront_outlined,
                                        size: 13, color: _textMuted),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: Text(
                                      farmer.isEmpty ? 'Local farm' : farmer,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.3,
                                          color: _textMuted),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: ExcludeSemantics(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text.rich(
                                        TextSpan(
                                          text: price,
                                          children: [
                                            if (compact)
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
                                        style: TextStyle(
                                          fontSize: compact ? 16 : 17,
                                          height: 1.25,
                                          fontWeight: FontWeight.w800,
                                          color: canOrder
                                              ? _brand
                                              : const Color(0xFF6B7A5E),
                                          fontFeatures: const [
                                            FontFeature.tabularFigures()
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (!compact)
                                      Text(
                                        'per $unit',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            height: 1.3,
                                            color: _textMuted),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (addAction != null) ...[
                              const SizedBox(width: 4),
                              _AddButton(
                                itemName: product.itemName,
                                enabled: canOrder && !adding,
                                canOrder: canOrder,
                                busy: adding,
                                onTap: addAction,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
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

class _StockPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StockPill(
      {required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String itemName;
  final bool enabled;
  final bool canOrder;
  final bool busy;
  final VoidCallback onTap;

  const _AddButton({
    required this.itemName,
    required this.enabled,
    required this.canOrder,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: canOrder ? 'Add to cart' : 'Out of stock',
      child: Semantics(
        button: true,
        enabled: enabled,
        label: 'Add $itemName to cart',
        child: InkResponse(
          onTap: enabled ? onTap : null,
          radius: 24,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: canOrder ? _brand : const Color(0xFFE1E6DA),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: canOrder
                      ? [
                          BoxShadow(
                            color: _brand.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : const <BoxShadow>[],
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(9),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        Icons.add_rounded,
                        size: 22,
                        color:
                            canOrder ? Colors.white : const Color(0xFF9AA590),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F4EC), Color(0xFFE3E9DA)],
        ),
      ),
      child: Center(child: Icon(Icons.eco, color: Color(0xFF9CBB7F), size: 36)),
    );
  }
}

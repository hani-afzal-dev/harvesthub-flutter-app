import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../models/product_model.dart';
import '../../../providers/catalog_providers.dart';
import '../../../providers/farmer_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../services/cloudinary_service.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/async_error_view.dart';
import '../../../widgets/panel_ui.dart';
import 'product_form_screen.dart';
import 'stock_update_sheet.dart';
import '../crop_doctor_screen.dart';

class FarmerProductsScreen extends ConsumerStatefulWidget {
  final String farmerId;

  const FarmerProductsScreen({super.key, required this.farmerId});

  @override
  ConsumerState<FarmerProductsScreen> createState() =>
      _FarmerProductsScreenState();
}

class _FarmerProductsScreenState extends ConsumerState<FarmerProductsScreen> {
  static const _filterLabels = ['All', 'Low stock', 'Out of stock', 'Hidden'];

  int _filter = 0;
  final Set<String> _toggling = {};

  bool _isLow(ProductModel product) =>
      product.inStock && product.stockQty <= StockRules.lowStockThreshold;

  bool _matches(ProductModel product, int filter) {
    switch (filter) {
      case 1:
        return _isLow(product);
      case 2:
        return !product.inStock;
      case 3:
        return !product.isAvailable;
      default:
        return true;
    }
  }

  void _openForm([ProductModel? product]) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          ProductFormScreen(farmerId: widget.farmerId, existing: product),
    ));
  }

  Future<void> _toggleListed(ProductModel product, bool value) async {
    if (_toggling.contains(product.productId)) return;
    HapticFeedback.selectionClick();
    setState(() => _toggling.add(product.productId));
    try {
      await ref
          .read(productServiceProvider)
          .setAvailability(product.productId, value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
            'Could not update ${product.itemName}. Try again.',
            tone: SnackTone.error));
      }
    } finally {
      if (mounted) setState(() => _toggling.remove(product.productId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(farmerProductsProvider(widget.farmerId));
    final categoryNames =
        ref.watch(categoryNameMapProvider).valueOrNull ?? const {};

    Widget body;
    if (productsAsync.hasError && !productsAsync.hasValue) {
      body = AsyncErrorView(
        title: 'Products did not load',
        message: 'Check your connection and try again.',
        onRetry: () => ref.invalidate(farmerProductsProvider(widget.farmerId)),
      );
    } else if (!productsAsync.hasValue) {
      body = const Center(
          child: CircularProgressIndicator(color: PanelColors.brand));
    } else {
      final products = productsAsync.value!;
      if (products.isEmpty) {
        body = ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          children: [
            _buildCropDoctorEntryCard(context),
            const SizedBox(height: 16),
            PanelEmptyState(
              icon: Icons.eco_outlined,
              title: 'No products yet',
              message: 'List your first item so customers can find and order it.',
              actionLabel: 'Add product',
              onAction: _openForm,
            ),
          ],
        );
      } else {
        final counts = List<int>.generate(
          _filterLabels.length,
          (i) => products.where((p) => _matches(p, i)).length,
        );
        final visible = products.where((p) => _matches(p, _filter)).toList();

        body = CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    PanelStatStrip(stats: [
                      ('${products.length}', 'Products'),
                      ('${counts[1] + counts[2]}', 'Need restock'),
                      ('${counts[3]}', 'Hidden'),
                    ]),
                    const SizedBox(height: 12),
                    _buildCropDoctorEntryCard(context),
                  ],
                ),
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
              const SliverFillRemaining(
                hasScrollBody: false,
                child: PanelEmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Nothing here',
                  message: 'No products match this filter right now.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                sliver: SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = visible[index];
                    return _ProductCard(
                      key: ValueKey('farmer_product_${product.productId}'),
                      product: product,
                      categoryName: categoryNames[product.categoryId] ?? '',
                      toggling: _toggling.contains(product.productId),
                      onToggleListed: (value) => _toggleListed(product, value),
                      onEdit: () => _openForm(product),
                      onUpdateStock: () =>
                          showStockUpdateSheet(context, ref, product),
                    );
                  },
                ),
              ),
          ],
        );
      }
    }

    final count = productsAsync.valueOrNull?.length;
    var subtitle = 'Manage what customers can buy';
    if (count != null && count > 0) {
      subtitle = '$count ${count == 1 ? 'item' : 'items'} in your shop';
    }

    return Scaffold(
      backgroundColor: PanelColors.pageBg,
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('farmer_add_product_button'),
        backgroundColor: PanelColors.brand,
        foregroundColor: Colors.white,
        onPressed: _openForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add product',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            PanelHeader(title: 'My Products', subtitle: subtitle),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _buildCropDoctorEntryCard(BuildContext context) {
    return PanelCard(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const CropDoctorScreen(),
        ));
      },
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PanelColors.tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.healing_rounded,
              color: PanelColors.brand,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crop Doctor - check a sick plant',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: PanelColors.brand,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Photograph a leaf to get safe AI health tips',
                  style: TextStyle(fontSize: 12, color: PanelColors.textMuted),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: PanelColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final String categoryName;
  final bool toggling;
  final ValueChanged<bool> onToggleListed;
  final VoidCallback onEdit;
  final VoidCallback onUpdateStock;

  const _ProductCard({
    super.key,
    required this.product,
    required this.categoryName,
    required this.toggling,
    required this.onToggleListed,
    required this.onEdit,
    required this.onUpdateStock,
  });

  @override
  Widget build(BuildContext context) {
    var stockLabel = '${product.stockQty} ${product.unit} in stock';
    var stockColor = PanelColors.brand;
    var stockBg = PanelColors.tint;
    var stockIcon = Icons.check_circle_outline_rounded;
    if (!product.inStock) {
      stockLabel = 'Out of stock';
      stockColor = PanelColors.danger;
      stockBg = PanelColors.dangerBg;
      stockIcon = Icons.block_rounded;
    } else if (product.stockQty <= StockRules.lowStockThreshold) {
      stockLabel = 'Only ${product.stockQty} left';
      stockColor = PanelColors.amber;
      stockBg = PanelColors.amberBg;
      stockIcon = Icons.local_fire_department_outlined;
    }

    final imageUrl = product.imageUrl;
    return PanelCard(
      onTap: onEdit,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: product.hasImage && imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: CloudinaryService.optimizedUrl(imageUrl,
                              width: 200),
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const ColoredBox(color: PanelColors.tint),
                          errorWidget: (context, url, error) => const _Thumb(),
                        )
                      : const _Thumb(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (categoryName.isNotEmpty)
                      Text(
                        categoryName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Color(0xFF3B6D11)),
                      ),
                    Text(
                      product.itemName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: PanelColors.textMain),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        text: 'Rs. ${product.pricePerUnit.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: PanelColors.brand,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                        children: [
                          TextSpan(
                            text: ' / ${product.unit}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: PanelColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    StatusPill(
                      label: stockLabel,
                      icon: stockIcon,
                      color: stockColor,
                      background: stockBg,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: PanelColors.border),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: MergeSemantics(
                  child: Row(
                    children: [
                      Switch(
                        value: product.isAvailable,
                        activeTrackColor: PanelColors.brand,
                        onChanged: toggling ? null : onToggleListed,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          product.isAvailable ? 'Visible' : 'Hidden',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: product.isAvailable
                                ? PanelColors.brand
                                : PanelColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onUpdateStock,
                style: TextButton.styleFrom(
                  foregroundColor: PanelColors.textBody,
                  minimumSize: const Size(0, 44),
                ),
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('Stock'),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  foregroundColor: PanelColors.brand,
                  minimumSize: const Size(0, 44),
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb();

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
      child: Center(child: Icon(Icons.eco, color: Color(0xFF9CBB7F))),
    );
  }
}

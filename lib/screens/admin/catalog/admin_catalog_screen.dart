import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../models/category_model.dart';
import '../../../models/product_model.dart';
import '../../../providers/admin_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../services/category_service.dart';
import '../../../services/cloudinary_service.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/async_error_view.dart';
import '../../../widgets/image_upload_field.dart';
import '../../../widgets/panel_ui.dart';

class AdminCatalogScreen extends StatefulWidget {
  const AdminCatalogScreen({super.key});

  @override
  State<AdminCatalogScreen> createState() => _AdminCatalogScreenState();
}

class _AdminCatalogScreenState extends State<AdminCatalogScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(_onTabChanged);

  void _onTabChanged() {
    if (!_tabs.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PanelColors.pageBg,
      floatingActionButton: _tabs.index == 1
          ? Consumer(
              builder: (context, ref, _) => FloatingActionButton.extended(
                key: const ValueKey('admin_add_category_button'),
                backgroundColor: PanelColors.brand,
                foregroundColor: Colors.white,
                onPressed: () => showCategorySheet(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add category',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            )
          : null,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const PanelHeader(
              title: 'Catalog',
              subtitle: 'Products and the categories they belong to',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: PanelColors.border),
                ),
                child: TabBar(
                  controller: _tabs,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: PanelColors.brand,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: PanelColors.textBody,
                  labelStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                  tabs: const [Tab(text: 'Products'), Tab(text: 'Categories')],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [_AdminProductList(), _AdminCategoryList()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminProductList extends ConsumerStatefulWidget {
  const _AdminProductList();

  @override
  ConsumerState<_AdminProductList> createState() => _AdminProductListState();
}

class _AdminProductListState extends ConsumerState<_AdminProductList>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  final Set<String> _busy = {};
  String _query = '';
  String? _categoryId;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleVisible(ProductModel product) async {
    if (_busy.contains(product.productId)) return;
    final show = !product.isAvailable;
    setState(() => _busy.add(product.productId));
    try {
      await ref
          .read(productServiceProvider)
          .setAvailability(product.productId, show);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
          show
              ? '${product.itemName} is visible to customers again'
              : '${product.itemName} is now hidden from customers',
          tone: SnackTone.success));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
          'Could not update ${product.itemName}. Please try again.',
          tone: SnackTone.error));
    } finally {
      if (mounted) setState(() => _busy.remove(product.productId));
    }
  }

  Future<void> _delete(ProductModel product) async {
    if (_busy.contains(product.productId)) return;
    final confirmed = await showPanelConfirm(
      context,
      title: 'Remove ${product.itemName}?',
      message:
          'This permanently removes it from the marketplace and the farmer\'s shop.',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy.add(product.productId));
    try {
      await ref.read(productServiceProvider).deleteProduct(product.productId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar('${product.itemName} removed', tone: SnackTone.success));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
          'Could not remove the product. Please try again.',
          tone: SnackTone.error));
    } finally {
      if (mounted) setState(() => _busy.remove(product.productId));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final productsAsync = ref.watch(adminProductsProvider);
    final categories = ref.watch(adminCategoriesProvider).valueOrNull ??
        const <CategoryModel>[];
    final categoryNames = {for (final c in categories) c.categoryId: c.name};
    final farmerNames = <String, String>{};
    for (final farmer
        in ref.watch(adminFarmerProfilesProvider).valueOrNull ?? const []) {
      farmerNames[farmer.farmerId] = farmer.businessName;
    }

    if (productsAsync.hasError && !productsAsync.hasValue) {
      return AsyncErrorView(
        message: 'Could not load products.',
        onRetry: () => ref.invalidate(adminProductsProvider),
      );
    }
    if (!productsAsync.hasValue) {
      return const Center(
          child: CircularProgressIndicator(color: PanelColors.brand));
    }
    final products = productsAsync.value!;
    if (products.isEmpty) {
      return const PanelEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No products listed yet',
        message: 'Products appear here once farmers add them to their shops.',
      );
    }

    final searched = products
        .where((p) =>
            matchesSearch(_query, [p.itemName, farmerNames[p.farmerId] ?? '']))
        .toList();
    final chipIds = <String?>[null];
    final labels = <String>['All'];
    final counts = <int>[searched.length];
    for (final category in categories) {
      final count =
          searched.where((p) => p.categoryId == category.categoryId).length;
      if (count == 0 && _categoryId != category.categoryId) continue;
      chipIds.add(category.categoryId);
      labels.add(category.name);
      counts.add(count);
    }
    var selected = chipIds.indexOf(_categoryId);
    if (selected < 0) selected = 0;
    final visible = searched
        .where((p) => _categoryId == null || p.categoryId == _categoryId)
        .toList();

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: PanelSearchField(
            controller: _searchController,
            hint: 'Search products or farms',
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        SliverToBoxAdapter(
          child: FilterChipBar(
            labels: labels,
            counts: counts,
            selected: selected,
            onSelected: (i) => setState(() => _categoryId = chipIds[i]),
          ),
        ),
        if (visible.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: PanelEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matches',
              message: 'Try a different search or category.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: SliverList.separated(
              itemCount: visible.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final product = visible[index];
                return _ProductTile(
                  key: ValueKey('admin_product_${product.productId}'),
                  product: product,
                  categoryName:
                      categoryNames[product.categoryId] ?? 'Uncategorised',
                  farmerName: farmerNames[product.farmerId],
                  busy: _busy.contains(product.productId),
                  onToggleVisible: () => _toggleVisible(product),
                  onDelete: () => _delete(product),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  final ProductModel product;
  final String categoryName;
  final String? farmerName;
  final bool busy;
  final VoidCallback onToggleVisible;
  final VoidCallback onDelete;

  const _ProductTile({
    super.key,
    required this.product,
    required this.categoryName,
    required this.farmerName,
    required this.busy,
    required this.onToggleVisible,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    String? stockLabel;
    var stockColor = PanelColors.amber;
    var stockBg = PanelColors.amberBg;
    var stockIcon = Icons.local_fire_department_outlined;
    if (!product.inStock) {
      stockLabel = 'Out of stock';
      stockColor = PanelColors.danger;
      stockBg = PanelColors.dangerBg;
      stockIcon = Icons.block_rounded;
    } else if (product.stockQty <= StockRules.lowStockThreshold) {
      stockLabel = 'Only ${product.stockQty} left';
    }
    final stock = stockLabel;
    final meta = [categoryName, if (farmerName != null) farmerName!];
    final imageUrl = product.imageUrl;

    return PanelCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: product.hasImage && imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl:
                          CloudinaryService.optimizedUrl(imageUrl, width: 200),
                      fit: BoxFit.cover,
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
                Text(
                  product.itemName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: PanelColors.textMain),
                ),
                Text(
                  meta.join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: PanelColors.textMuted),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: 'Rs. ${product.pricePerUnit.toStringAsFixed(0)}',
                        children: [
                          TextSpan(
                            text: '/${product.unit}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: PanelColors.textMuted),
                          ),
                          if (stock == null)
                            TextSpan(
                              text: '  ·  ${product.stockQty} in stock',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: PanelColors.textMuted),
                            ),
                        ],
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: PanelColors.brand,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (stock != null)
                      StatusPill(
                        label: stock,
                        icon: stockIcon,
                        color: stockColor,
                        background: stockBg,
                      ),
                    if (!product.isAvailable)
                      const StatusPill(
                        label: 'Hidden',
                        icon: Icons.visibility_off_outlined,
                        color: PanelColors.textMuted,
                        background: PanelColors.greyBg,
                      ),
                  ],
                ),
              ],
            ),
          ),
          busy
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: PanelColors.danger),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: product.isAvailable
                          ? 'Hide ${product.itemName} from customers'
                          : 'Show ${product.itemName} to customers',
                      onPressed: onToggleVisible,
                      icon: Icon(
                        product.isAvailable
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: product.isAvailable
                            ? PanelColors.brand
                            : PanelColors.textMuted,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove ${product.itemName}',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: PanelColors.danger),
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

class _AdminCategoryList extends ConsumerStatefulWidget {
  const _AdminCategoryList();

  @override
  ConsumerState<_AdminCategoryList> createState() => _AdminCategoryListState();
}

class _AdminCategoryListState extends ConsumerState<_AdminCategoryList>
    with AutomaticKeepAliveClientMixin {
  final Set<String> _busy = {};

  @override
  bool get wantKeepAlive => true;

  Future<void> _toggleActive(CategoryModel category, bool value) async {
    if (_busy.contains(category.categoryId)) return;
    HapticFeedback.selectionClick();
    setState(() => _busy.add(category.categoryId));
    try {
      await ref
          .read(categoryServiceProvider)
          .setActive(category.categoryId, value);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
          'Could not update ${category.name}. Please try again.',
          tone: SnackTone.error));
    } finally {
      if (mounted) setState(() => _busy.remove(category.categoryId));
    }
  }

  Future<void> _delete(CategoryModel category, int productCount) async {
    if (_busy.contains(category.categoryId)) return;
    if (productCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
        '${category.name} still has $productCount ${productCount == 1 ? 'product' : 'products'}. Move or remove them first.',
        tone: SnackTone.error,
      ));
      return;
    }
    final confirmed = await showPanelConfirm(
      context,
      title: 'Delete ${category.name}?',
      message: 'This category will be removed for everyone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy.add(category.categoryId));
    try {
      await ref
          .read(categoryServiceProvider)
          .deleteCategory(category.categoryId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar('${category.name} deleted', tone: SnackTone.success));
    } on CategoryInUseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(appSnackBar(e.toString(), tone: SnackTone.error));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
          'Could not delete ${category.name}. Please try again.',
          tone: SnackTone.error));
    } finally {
      if (mounted) setState(() => _busy.remove(category.categoryId));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final categoriesAsync = ref.watch(adminCategoriesProvider);
    final products =
        ref.watch(adminProductsProvider).valueOrNull ?? const <ProductModel>[];

    if (categoriesAsync.hasError && !categoriesAsync.hasValue) {
      return AsyncErrorView(
        message: 'Could not load categories.',
        onRetry: () => ref.invalidate(adminCategoriesProvider),
      );
    }
    if (!categoriesAsync.hasValue) {
      return const Center(
          child: CircularProgressIndicator(color: PanelColors.brand));
    }
    final categories = categoriesAsync.value!;
    if (categories.isEmpty) {
      return PanelEmptyState(
        icon: Icons.category_outlined,
        title: 'No categories yet',
        message:
            'Farmers need at least one category before they can list products.',
        actionLabel: 'Add category',
        onAction: () => showCategorySheet(context, ref),
      );
    }

    final productCounts = <String, int>{};
    for (final product in products) {
      productCounts[product.categoryId] =
          (productCounts[product.categoryId] ?? 0) + 1;
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final category = categories[index];
        final count = productCounts[category.categoryId] ?? 0;
        final busy = _busy.contains(category.categoryId);
        final imageUrl = category.imageUrl;

        return PanelCard(
          key: ValueKey('admin_category_${category.categoryId}'),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: CloudinaryService.optimizedUrl(imageUrl,
                                  width: 160),
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  const _Thumb(),
                            )
                          : const _Thumb(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: PanelColors.textMain)),
                        Text(
                          '$count ${count == 1 ? 'product' : 'products'}',
                          style: const TextStyle(
                              fontSize: 12, color: PanelColors.textMuted),
                        ),
                        if (category.description.isNotEmpty)
                          Text(category.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: PanelColors.textBody)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Divider(height: 1, color: PanelColors.border),
              Row(
                children: [
                  Expanded(
                    child: MergeSemantics(
                      child: Row(
                        children: [
                          SizedBox(
                            height: 40,
                            child: FittedBox(
                              child: Switch(
                                value: category.isActive,
                                activeTrackColor: PanelColors.brand,
                                onChanged: busy
                                    ? null
                                    : (value) => _toggleActive(category, value),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              category.isActive ? 'Shown in app' : 'Hidden',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: PanelColors.textBody),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit ${category.name}',
                    onPressed: busy
                        ? null
                        : () =>
                            showCategorySheet(context, ref, existing: category),
                    icon: const Icon(Icons.edit_outlined,
                        color: PanelColors.brand),
                  ),
                  IconButton(
                    tooltip: 'Delete ${category.name}',
                    onPressed: busy ? null : () => _delete(category, count),
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: PanelColors.danger),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> showCategorySheet(BuildContext context, WidgetRef ref,
    {CategoryModel? existing}) {
  final service = ref.read(categoryServiceProvider);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _CategorySheet(service: service, existing: existing),
  );
}

class _CategorySheet extends StatefulWidget {
  final CategoryService service;
  final CategoryModel? existing;

  const _CategorySheet({required this.service, this.existing});

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.existing?.description ?? '');
  late String? _imageUrl = widget.existing?.imageUrl;
  bool _saving = false;
  bool _submitted = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? get _nameError {
    final name = _nameController.text.trim();
    if (name.length < 2) return 'Use at least 2 characters.';
    if (name.length > 40) return 'Keep it under 40 characters.';
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (_nameError != null) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final name = _nameController.text.trim();
    try {
      final existing = widget.existing;
      if (existing != null) {
        await widget.service.updateCategory(
          existing.categoryId,
          name: name,
          description: _descriptionController.text,
          imageUrl: _imageUrl,
          isActive: existing.isActive,
        );
      } else {
        await widget.service.addCategory(name,
            description: _descriptionController.text, imageUrl: _imageUrl);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(appSnackBar(
          _isEditing ? '$name updated' : '$name added',
          tone: SnackTone.success));
    } on CategoryNameTakenException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Could not save the category. Check your connection and try again.';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: PanelColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(_isEditing ? 'Edit category' : 'New category',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: PanelColors.textMain)),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ImageUploadField(
                    size: 88,
                    initialImageUrl: _imageUrl,
                    onUploaded: (url) => setState(() => _imageUrl = url),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'A simple photo helps customers spot the category on the home screen.',
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: PanelColors.textMuted),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('category_name_field'),
                controller: _nameController,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(40)],
                onChanged: (_) => setState(() {}),
                decoration: panelInputDecoration('Category name',
                    hint: 'e.g. Fruits', error: _submitted ? _nameError : null),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('category_description_field'),
                controller: _descriptionController,
                enabled: !_saving,
                minLines: 2,
                maxLines: 3,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    panelInputDecoration('Short description (optional)'),
              ),
              if (error != null) ...[
                const SizedBox(height: 4),
                Text(error,
                    style: const TextStyle(
                        fontSize: 13, color: PanelColors.danger)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton(
                  key: const ValueKey('category_save_button'),
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: PanelColors.brand,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: PanelColors.brand),
                        )
                      : Text(_isEditing ? 'Save changes' : 'Add category',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

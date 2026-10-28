import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_logger.dart';
import '../../../core/constants.dart';
import '../../../models/category_model.dart';
import '../../../models/product_model.dart';
import '../../../providers/catalog_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../providers/session_providers.dart';
import '../../../services/cloudinary_service.dart';
import '../../../widgets/offline_banner.dart';
import '../../../widgets/load_more_button.dart';
import '../../../widgets/product_card.dart';
import '../../../widgets/unread_badge.dart';
import '../notifications/notifications_screen.dart';
import 'catalog_filter_sheet.dart';
import 'product_details_screen.dart';
import '../smart_basket_screen.dart';
import '../../../widgets/app_snackbar.dart';

const Color _brand = Color(0xFF3B6D11);
const Color _textMain = Color(0xFF22301A);
const Color _textMuted = Color(0xFF6B7A5E);
const Color _pageBg = Color(0xFFF6F8F3);

const List<String> _homeCategoryPriority = [
  'Organic Products',
  'Fruits',
  'Vegetables',
  'Grains',
];

List<CategoryModel> _orderedForHome(List<CategoryModel> categories) {
  final prioritized = <CategoryModel>[];
  for (final name in _homeCategoryPriority) {
    final match = categories.where((c) => c.name == name);
    if (match.isNotEmpty) prioritized.add(match.first);
  }
  final rest =
      categories.where((c) => !_homeCategoryPriority.contains(c.name));
  return [...prioritized, ...rest];
}

class HomeCatalogScreen extends ConsumerStatefulWidget {
  const HomeCatalogScreen({super.key});

  @override
  ConsumerState<HomeCatalogScreen> createState() => _HomeCatalogScreenState();
}

class _HomeCatalogScreenState extends ConsumerState<HomeCatalogScreen> {
  final _searchController = TextEditingController();
  final Set<String> _adding = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFilters(
      CatalogFilterOptions options, CatalogFilters current) async {
    final result = await showModalBottomSheet<CatalogFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => CatalogFilterSheet(
        markets: options.markets,
        farmers: options.farmers,
        current: current,
        userPosition: current.position,
      ),
    );
    if (result != null) {
      ref.read(catalogProvider.notifier).setFilters(result);
    }
  }

  void _openDetails(ProductModel product) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(productId: product.productId)),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(productSearchProvider.notifier).search('');
    FocusScope.of(context).unfocus();
  }

  Future<void> _addToCart(ProductModel product) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || _adding.contains(product.productId)) return;
    setState(() => _adding.add(product.productId));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(cartServiceProvider)
          .addOrIncrement(userId: uid, productId: product.productId);
      HapticFeedback.lightImpact();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(appSnackBar('${product.itemName} added to cart.',
          tone: SnackTone.success));
    } catch (e, stack) {
      AppLogger.error('Home add to cart failed', e, stack);
      messenger.showSnackBar(appSnackBar(
          'Could not add ${product.itemName}. Try again.',
          tone: SnackTone.error));
    } finally {
      if (mounted) setState(() => _adding.remove(product.productId));
    }
  }

  Future<void> _refresh(String? categoryId) async {
    final ids = <String?>[categoryId];
    if (categoryId == null) {
      final categories = ref.read(activeCategoriesProvider).valueOrNull ??
          const <CategoryModel>[];
      ids.addAll(categories.map((c) => c.categoryId));
    }
    for (final id in ids) {
      ref.invalidate(catalogProductsProvider(id));
    }
    try {
      await Future.wait(
          ids.map((id) => ref.read(catalogProductsProvider(id).future)));
    } catch (_) {
      return;
    }
  }

  bool _groupedView(String? categoryId) {
    if (categoryId != null) return false;
    if (_searchController.text.trim().isNotEmpty) return false;
    final categories = ref.read(activeCategoriesProvider).valueOrNull;
    return categories != null && categories.isNotEmpty;
  }

  List<ProductModel> _filtered(List<ProductModel> products,
      CatalogFilters filters, CatalogFilterOptions options) {
    return applyCatalogFilters(
      products: products,
      filters: filters,
      options: options,
      marketService: ref.read(marketServiceProvider),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final options = ref.watch(catalogFilterOptionsProvider).valueOrNull ??
        const CatalogFilterOptions();
    final categories = _orderedForHome(
        ref.watch(activeCategoriesProvider).valueOrNull ??
            const <CategoryModel>[]);
    final profile = ref.watch(sessionProfileProvider).valueOrNull;
    final uid = ref.watch(currentUidProvider);
    final filters = catalog.filters;
    final searching = _searchController.text.trim().isNotEmpty;

    var firstName = '';
    if (profile != null && profile.name.trim().isNotEmpty) {
      firstName = profile.name.trim().split(RegExp(r'\s+')).first;
    }

    final grouped = _groupedView(catalog.categoryId);
    var sectionTitle = 'Fresh picks for you';
    if (grouped) {
      sectionTitle = 'Shop by category';
    } else if (searching) {
      sectionTitle = 'Search results';
    } else {
      for (final category in categories) {
        if (category.categoryId == catalog.categoryId) {
          sectionTitle = category.name;
        }
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _pageBg,
        body: RefreshIndicator(
          color: _brand,
          edgeOffset: MediaQuery.paddingOf(context).top,
          onRefresh: () => _refresh(catalog.categoryId),
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: _HomeHeader(
                  greeting: firstName.isEmpty
                      ? _greeting()
                      : '${_greeting()}, $firstName',
                  searchController: _searchController,
                  onSearchChanged: (query) {
                    setState(() {});
                    ref.read(productSearchProvider.notifier).search(query);
                  },
                  onClearSearch: _clearSearch,
                  filtersActive: !filters.isEmpty,
                  onOpenFilters: () => _openFilters(options, filters),
                  onOpenNotifications: uid == null
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    NotificationsScreen(userId: uid)),
                          ),
                ),
              ),
              const SliverToBoxAdapter(child: OfflineBanner()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: _buildSmartBasketCard(context),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 84 +
                      MediaQuery.textScalerOf(context).scale(12) * 1.2 * 2 +
                      6,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
                    children: [
                      _CategoryTile(
                        label: 'All',
                        imageUrl: null,
                        fallbackIcon: Icons.grid_view_rounded,
                        selected: catalog.categoryId == null,
                        onTap: () => ref
                            .read(catalogProvider.notifier)
                            .selectCategory(null),
                      ),
                      for (final category in categories)
                        _CategoryTile(
                          label: category.name,
                          imageUrl: category.imageUrl,
                          selected: catalog.categoryId == category.categoryId,
                          onTap: () => ref
                              .read(catalogProvider.notifier)
                              .selectCategory(category.categoryId),
                        ),
                    ],
                  ),
                ),
              ),
              if (!grouped || !filters.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            sectionTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _textMain),
                          ),
                        ),
                        if (!filters.isEmpty)
                          TextButton.icon(
                            onPressed: () => ref
                                .read(catalogProvider.notifier)
                                .setFilters(const CatalogFilters()),
                            style: TextButton.styleFrom(
                                foregroundColor: _brand,
                                minimumSize: const Size(48, 40)),
                            icon: const Icon(Icons.filter_alt_off_outlined,
                                size: 18),
                            label: const Text('Clear filters',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                  ),
                ),
              ..._contentSlivers(catalog, options),
              SliverToBoxAdapter(
                  child: SizedBox(
                      height: 96 + MediaQuery.paddingOf(context).bottom)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmartBasketCard(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('home_smart_basket_card'),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const SmartBasketScreen(),
        ));
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F7EC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD6E8CD)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _brand,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shopping_basket_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Basket - tell us what you need',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textMain,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'AI builds your basket within budget & stock',
                    style: TextStyle(fontSize: 12, color: _textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: _textMuted),
          ],
        ),
      ),
    );
  }

  List<Widget> _contentSlivers(
      CatalogState catalog, CatalogFilterOptions options) {
    final search = ref.watch(productSearchProvider);
    final searchResults = search.results;

    if (search.loading) return [const _LoadingGrid()];

    if (search.failed) {
      return [
        _MessageSliver(
          icon: Icons.search_off_rounded,
          title: 'Search did not go through',
          message: 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: () => ref
              .read(productSearchProvider.notifier)
              .search(_searchController.text),
        ),
      ];
    }

    if (searchResults != null) {
      final categoryId = catalog.categoryId;
      final inCategory = categoryId == null
          ? searchResults
          : searchResults.where((p) => p.categoryId == categoryId).toList();
      return _gridSlivers(
        _filtered(inCategory, catalog.filters, options),
        emptyTitle: 'No products match "${_searchController.text.trim()}"',
      );
    }

    if (_groupedView(catalog.categoryId)) {
      return _groupedSlivers(catalog, options);
    }

    final productsAsync =
        ref.watch(catalogProductsProvider(catalog.categoryId));
    return productsAsync.when(
      skipLoadingOnReload: true,
      loading: () => [const _LoadingGrid()],
      error: (_, __) => _offlineSlivers(catalog, options),
      data: (products) {
        final limit = ref.watch(catalogPageLimitProvider(catalog.categoryId));
        final hasMore = products.length >= limit;
        return _gridSlivers(
          _filtered(products, catalog.filters, options),
          emptyTitle: 'No products here yet',
          onLoadMore: hasMore
              ? () => ref
                  .read(catalogPageLimitProvider(catalog.categoryId).notifier)
                  .state += PagingRules.pageSize
              : null,
        );
      },
    );
  }

  List<Widget> _groupedSlivers(
      CatalogState catalog, CatalogFilterOptions options) {
    final categories = _orderedForHome(
        ref.watch(activeCategoriesProvider).valueOrNull ??
            const <CategoryModel>[]);
    final loaded = <String, List<ProductModel>>{};
    final loading = <String>{};
    var failed = false;
    for (final category in categories) {
      final async = ref.watch(catalogProductsProvider(category.categoryId));
      final data = async.valueOrNull;
      if (data != null) {
        loaded[category.categoryId] = data;
      } else if (async.hasError) {
        failed = true;
      } else {
        loading.add(category.categoryId);
      }
    }

    final slivers = <Widget>[];
    if (failed) {
      final cached = ref.watch(cachedProductsProvider).valueOrNull ??
          const <ProductModel>[];
      if (cached.isEmpty && loaded.isEmpty && loading.isEmpty) {
        return _offlineSlivers(catalog, options);
      }
      for (final category in categories) {
        if (loaded.containsKey(category.categoryId) ||
            loading.contains(category.categoryId)) {
          continue;
        }
        loaded[category.categoryId] =
            cached.where((p) => p.categoryId == category.categoryId).toList();
      }
      slivers.add(const SliverToBoxAdapter(
        child: OfflineNotice(
            message: "You're offline. Showing products from your last visit."),
      ));
    }

    if (loaded.isEmpty) return [const _LoadingGrid()];

    final farmerNames = <String, String>{};
    for (final farmer in options.farmers) {
      farmerNames[farmer.farmerId] = farmer.businessName;
    }
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = ((screenWidth - 44) / 2.4).clamp(140.0, 190.0);
    final cardHeight = ProductCard.heightFor(
        cardWidth, MediaQuery.textScalerOf(context),
        compact: true);

    var rows = 0;
    for (final category in categories) {
      if (loading.contains(category.categoryId)) {
        slivers.add(SliverToBoxAdapter(
          child: _CategoryRowSkeleton(
              title: category.name,
              cardWidth: cardWidth,
              cardHeight: cardHeight),
        ));
        continue;
      }
      final products =
          _filtered(loaded[category.categoryId]!, catalog.filters, options);
      if (products.isEmpty) continue;
      rows++;
      slivers.add(SliverToBoxAdapter(
        child: _CategoryRow(
          key: ValueKey('home_row_${category.categoryId}'),
          title: category.name,
          products: products,
          cardWidth: cardWidth,
          cardHeight: cardHeight,
          onSeeAll: () => ref
              .read(catalogProvider.notifier)
              .selectCategory(category.categoryId),
          itemBuilder: (product) => ProductCard(
            key: ValueKey('home_product_${product.productId}'),
            product: product,
            onTap: () => _openDetails(product),
            onAdd: () => _addToCart(product),
            adding: _adding.contains(product.productId),
            farmerName: farmerNames[product.farmerId],
            compact: true,
          ),
        ),
      ));
    }

    if (rows == 0 && loading.isEmpty) {
      return [
        ...slivers,
        ..._gridSlivers(const [], emptyTitle: 'No products here yet'),
      ];
    }
    return slivers;
  }

  List<Widget> _offlineSlivers(
      CatalogState catalog, CatalogFilterOptions options) {
    final cached =
        ref.watch(cachedProductsProvider).valueOrNull ?? const <ProductModel>[];
    if (cached.isEmpty) {
      return [
        _MessageSliver(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load products',
          message: 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: () =>
              ref.invalidate(catalogProductsProvider(catalog.categoryId)),
        ),
      ];
    }
    return [
      const SliverToBoxAdapter(
        child: OfflineNotice(
            message: "You're offline. Showing products from your last visit."),
      ),
      ..._gridSlivers(_filtered(cached, catalog.filters, options),
          emptyTitle: 'No saved products'),
    ];
  }

  List<Widget> _gridSlivers(List<ProductModel> products,
      {required String emptyTitle, VoidCallback? onLoadMore}) {
    final filtersActive = !ref.read(catalogProvider).filters.isEmpty;

    if (products.isEmpty) {
      var message = 'Check back soon, farmers add fresh stock every day.';
      String? actionLabel;
      VoidCallback? action;
      if (filtersActive) {
        message = 'Try clearing your filters to see more produce.';
        actionLabel = 'Clear filters';
        action = () => ref
            .read(catalogProvider.notifier)
            .setFilters(const CatalogFilters());
      } else if (onLoadMore != null) {
        actionLabel = 'Load more';
        action = onLoadMore;
      }
      return [
        _MessageSliver(
          icon: Icons.eco_outlined,
          title: emptyTitle,
          message: message,
          actionLabel: actionLabel,
          onAction: action,
        ),
      ];
    }

    final textScaler = MediaQuery.textScalerOf(context);

    final farmerNames = <String, String>{};
    final options = ref.read(catalogFilterOptionsProvider).valueOrNull;
    for (final farmer in options?.farmers ?? const []) {
      farmerNames[farmer.farmerId] = farmer.businessName;
    }
    final categoryNames = <String, String>{};
    final categories = ref.read(activeCategoriesProvider).valueOrNull;
    for (final category in categories ?? const <CategoryModel>[]) {
      categoryNames[category.categoryId] = category.name;
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final width = constraints.crossAxisExtent;
            var columns = (width / 200).floor();
            if (columns < 2) columns = 2;
            final cardWidth = (width - spacing * (columns - 1)) / columns;
            final extent = ProductCard.heightFor(cardWidth, textScaler);

            return SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                mainAxisExtent: extent,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = products[index];
                  return ProductCard(
                    key: ValueKey('home_product_${product.productId}'),
                    product: product,
                    onTap: () => _openDetails(product),
                    onAdd: () => _addToCart(product),
                    adding: _adding.contains(product.productId),
                    farmerName: farmerNames[product.farmerId],
                    categoryName: categoryNames[product.categoryId],
                  );
                },
                childCount: products.length,
              ),
            );
          },
        ),
      ),
      if (onLoadMore != null)
        SliverToBoxAdapter(child: LoadMoreButton(onPressed: onLoadMore)),
    ];
  }
}

class _HomeHeader extends StatelessWidget {
  final String greeting;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final bool filtersActive;
  final VoidCallback onOpenFilters;
  final VoidCallback? onOpenNotifications;

  const _HomeHeader({
    required this.greeting,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.filtersActive,
    required this.onOpenFilters,
    required this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final openNotifications = onOpenNotifications;

    return Container(
      padding: EdgeInsets.fromLTRB(20, topInset + 16, 16, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A9A1F), _brand, Color(0xFF2A4A0C)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'What would you like to pick up today?',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.88)),
                    ),
                  ],
                ),
              ),
              if (openNotifications != null)
                Material(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: const CircleBorder(),
                  child: IconButton(
                    key: const ValueKey('home_notifications_button'),
                    tooltip: 'Notifications',
                    onPressed: openNotifications,
                    icon: const UnreadBadge(
                        child: Icon(Icons.notifications_none_rounded,
                            color: Colors.white)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('home_search_field'),
                  controller: searchController,
                  onChanged: onSearchChanged,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 15, color: _textMain),
                  decoration: InputDecoration(
                    hintText: 'Search fruits, vegetables, dairy...',
                    hintStyle: const TextStyle(fontSize: 14, color: _textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, color: _brand),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded,
                                color: _textMuted),
                            onPressed: onClearSearch,
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: IconButton(
                      key: const ValueKey('home_filter_button'),
                      tooltip: filtersActive
                          ? 'Filters on. Change filters'
                          : 'Filter products',
                      onPressed: onOpenFilters,
                      constraints:
                          const BoxConstraints(minWidth: 52, minHeight: 52),
                      icon: const Icon(Icons.tune_rounded, color: _brand),
                    ),
                  ),
                  if (filtersActive)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF9F27),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final bool selected;
  final VoidCallback onTap;
  final IconData fallbackIcon;

  const _CategoryTile({
    required this.label,
    required this.imageUrl,
    required this.selected,
    required this.onTap,
    this.fallbackIcon = Icons.eco,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final fallback = Icon(fallbackIcon, color: _brand);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label category',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 76,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 60,
                height: 60,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? _brand : const Color(0xFFE3E9DA),
                    width: selected ? 2.5 : 1,
                  ),
                ),
                child: ClipOval(
                  child: ColoredBox(
                    color: const Color(0xFFEFF3EA),
                    child: url != null && url.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl:
                                CloudinaryService.optimizedUrl(url, width: 160),
                            fit: BoxFit.cover,
                            errorWidget: (context, _, __) => fallback,
                          )
                        : fallback,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? _brand : _textMain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRowHeader extends StatelessWidget {
  final String title;
  final int? count;
  final VoidCallback? onSeeAll;

  const _CategoryRowHeader({required this.title, this.count, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final seeAll = onSeeAll;
    final total = count;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
                color: _brand, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: _textMain),
            ),
          ),
          if (seeAll != null)
            TextButton(
              onPressed: seeAll,
              style: TextButton.styleFrom(
                  foregroundColor: _brand, minimumSize: const Size(48, 44)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(total == null ? 'See all' : 'See all ($total)',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  static const int maxItems = 10;

  final String title;
  final List<ProductModel> products;
  final double cardWidth;
  final double cardHeight;
  final VoidCallback onSeeAll;
  final Widget Function(ProductModel product) itemBuilder;

  const _CategoryRow({
    super.key,
    required this.title,
    required this.products,
    required this.cardWidth,
    required this.cardHeight,
    required this.onSeeAll,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final count = products.length;
    final shown = count > maxItems ? maxItems : count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryRowHeader(
          title: title,
          count: count,
          onSeeAll: onSeeAll,
        ),
        SizedBox(
          height: cardHeight + 20,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            itemCount: shown,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => SizedBox(
              width: cardWidth,
              child: itemBuilder(products[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryRowSkeleton extends StatelessWidget {
  final String title;
  final double cardWidth;
  final double cardHeight;

  const _CategoryRowSkeleton(
      {required this.title, required this.cardWidth, required this.cardHeight});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryRowHeader(title: title),
        SizedBox(
          height: cardHeight + 20,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => Container(
              width: cardWidth,
              decoration: BoxDecoration(
                  color: const Color(0xFFE9EEE3),
                  borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => Semantics(
            label: index == 0 ? 'Loading products' : null,
            child: Container(
              decoration: BoxDecoration(
                  color: const Color(0xFFE9EEE3),
                  borderRadius: BorderRadius.circular(18)),
            ),
          ),
          childCount: 6,
        ),
      ),
    );
  }
}

class _MessageSliver extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageSliver({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    final action = onAction;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 16),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Color(0xFFEFF3EA)),
              child: Icon(icon, size: 44, color: _brand),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: _textMain),
            ),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textMuted)),
            if (label != null && action != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: action,
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  minimumSize: const Size(180, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

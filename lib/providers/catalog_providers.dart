import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../core/app_logger.dart';
import '../core/constants.dart';
import '../models/category_model.dart';
import '../models/farmer_model.dart';
import '../models/market_model.dart';
import '../models/product_model.dart';
import '../services/market_service.dart';
import '../services/product_service.dart';
import 'service_providers.dart';

class CatalogFilters {
  final MarketModel? market;
  final FarmerModel? farmer;
  final double? maxDistanceKm;
  final Position? position;

  const CatalogFilters(
      {this.market, this.farmer, this.maxDistanceKm, this.position});

  bool get isEmpty => market == null && farmer == null && maxDistanceKm == null;
}

class CatalogFilterOptions {
  final List<MarketModel> markets;
  final List<FarmerModel> farmers;

  const CatalogFilterOptions(
      {this.markets = const [], this.farmers = const []});
}

class CatalogState {
  final String? categoryId;
  final CatalogFilters filters;

  const CatalogState({this.categoryId, this.filters = const CatalogFilters()});
}

class CatalogNotifier extends StateNotifier<CatalogState> {
  CatalogNotifier() : super(const CatalogState());

  void selectCategory(String? categoryId) {
    state = CatalogState(categoryId: categoryId, filters: state.filters);
  }

  void setFilters(CatalogFilters filters) {
    state = CatalogState(categoryId: state.categoryId, filters: filters);
  }
}

class ProductSearchState {
  final bool loading;
  final bool failed;
  final List<ProductModel>? results;

  const ProductSearchState(
      {this.loading = false, this.failed = false, this.results});
}

class ProductSearchNotifier extends StateNotifier<ProductSearchState> {
  final ProductService _productService;
  int _requestId = 0;

  ProductSearchNotifier(this._productService)
      : super(const ProductSearchState());

  Future<void> search(String query) async {
    final requestId = ++_requestId;
    if (query.trim().isEmpty) {
      state = const ProductSearchState();
      return;
    }

    state = const ProductSearchState(loading: true);
    try {
      final results = await _productService.searchByName(query);
      if (requestId != _requestId || !mounted) return;
      state = ProductSearchState(results: results);
    } catch (_) {
      if (requestId != _requestId || !mounted) return;
      state = const ProductSearchState(failed: true);
    }
  }
}

final catalogProvider =
    StateNotifierProvider.autoDispose<CatalogNotifier, CatalogState>((ref) {
  return CatalogNotifier();
});

final productSearchProvider = StateNotifierProvider.autoDispose<
    ProductSearchNotifier, ProductSearchState>((ref) {
  return ProductSearchNotifier(ref.watch(productServiceProvider));
});

final activeCategoriesProvider =
    StreamProvider.autoDispose<List<CategoryModel>>((ref) {
  return ref.watch(categoryServiceProvider).watchCategories(activeOnly: true);
});

final categoryNameMapProvider =
    FutureProvider.autoDispose<Map<String, String>>((ref) {
  return ref.watch(categoryServiceProvider).getNameMap();
});

final catalogFilterOptionsProvider =
    FutureProvider.autoDispose<CatalogFilterOptions>((ref) async {
  try {
    final markets = await ref.watch(marketServiceProvider).getActiveMarkets();
    final farmers = await ref.watch(farmerServiceProvider).getAllActive();
    return CatalogFilterOptions(markets: markets, farmers: farmers);
  } catch (e, stack) {
    AppLogger.error('Filter options failed to load', e, stack);
    rethrow;
  }
});

final catalogPageLimitProvider =
    StateProvider.autoDispose.family<int, String?>((ref, categoryId) {
  return PagingRules.pageSize;
});

final catalogProductsProvider = StreamProvider.autoDispose
    .family<List<ProductModel>, String?>((ref, categoryId) {
  final productService = ref.watch(productServiceProvider);
  final limit = ref.watch(catalogPageLimitProvider(categoryId));
  if (categoryId == null) {
    return productService.watchAllProducts(limit: limit);
  }
  return productService.watchByCategory(categoryId, limit: limit);
});

final cachedProductsProvider =
    FutureProvider.autoDispose<List<ProductModel>>((ref) {
  return ref.watch(productServiceProvider).getCachedProductsFallback();
});

List<ProductModel> applyCatalogFilters({
  required List<ProductModel> products,
  required CatalogFilters filters,
  required CatalogFilterOptions options,
  required MarketService marketService,
}) {
  if (filters.isEmpty) return products;

  final selectedMarket = filters.market;
  final selectedFarmer = filters.farmer;
  final maxDistance = filters.maxDistanceKm;
  final position = filters.position;

  Set<String>? marketFarmerIds;
  if (selectedMarket != null) {
    marketFarmerIds = options.farmers
        .where((farmer) => farmer.marketId == selectedMarket.marketId)
        .map((farmer) => farmer.farmerId)
        .toSet();
  }

  Set<String>? nearbyFarmerIds;
  if (maxDistance != null && position != null) {
    final nearbyMarketIds = <String>{};
    for (final entry
        in marketService.withDistanceFrom(options.markets, position)) {
      final distance = entry.distanceKm;
      if (distance != null && distance <= maxDistance) {
        nearbyMarketIds.add(entry.market.marketId);
      }
    }
    nearbyFarmerIds = options.farmers
        .where((farmer) => nearbyMarketIds.contains(farmer.marketId))
        .map((farmer) => farmer.farmerId)
        .toSet();
  }

  final filtered = <ProductModel>[];
  for (final product in products) {
    if (selectedFarmer != null && product.farmerId != selectedFarmer.farmerId) {
      continue;
    }
    if (marketFarmerIds != null &&
        !marketFarmerIds.contains(product.farmerId)) {
      continue;
    }
    if (nearbyFarmerIds != null &&
        !nearbyFarmerIds.contains(product.farmerId)) {
      continue;
    }
    filtered.add(product);
  }
  return filtered;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/farmer_model.dart';
import '../models/market_model.dart';
import '../models/product_model.dart';
import '../services/cart_service.dart';
import 'service_providers.dart';

class ProductDetailData {
  final ProductModel? product;
  final FarmerModel? farmer;
  final String categoryName;
  final MarketModel? market;

  const ProductDetailData(
      {this.product, this.farmer, this.categoryName = '', this.market});
}

class AddToCartNotifier extends StateNotifier<bool> {
  final CartService _cartService;

  AddToCartNotifier(this._cartService) : super(false);

  Future<bool> add(
      {required String uid,
      required String productId,
      int quantity = 1}) async {
    if (state) return false;
    state = true;
    try {
      await _cartService.addOrIncrement(
          userId: uid, productId: productId, quantity: quantity);
      return true;
    } catch (_) {
      return false;
    } finally {
      if (mounted) state = false;
    }
  }
}

final productDetailProvider = FutureProvider.autoDispose
    .family<ProductDetailData, String>((ref, productId) async {
  final product = await ref.watch(productServiceProvider).getById(productId);
  if (product == null) {
    return const ProductDetailData();
  }
  final farmerFuture =
      ref.watch(farmerServiceProvider).getById(product.farmerId);
  final namesFuture = ref.watch(categoryServiceProvider).getNameMap();
  final marketsFuture = ref
      .watch(marketServiceProvider)
      .getActiveMarkets()
      .catchError((Object _) => <MarketModel>[]);

  final (farmer, names, markets) =
      await (farmerFuture, namesFuture, marketsFuture).wait;

  MarketModel? market;
  final marketId = farmer?.marketId;
  for (final candidate in markets) {
    if (candidate.marketId == marketId) market = candidate;
  }

  return ProductDetailData(
    product: product,
    farmer: farmer,
    categoryName: names[product.categoryId] ?? '',
    market: market,
  );
});

final isWishlistedProvider = StreamProvider.autoDispose
    .family<bool, ({String uid, String productId})>((ref, key) {
  return ref
      .watch(wishlistServiceProvider)
      .watchIsWishlisted(key.uid, key.productId);
});

final isFollowingProvider = StreamProvider.autoDispose
    .family<bool, ({String uid, String farmerId})>((ref, key) {
  return ref
      .watch(followServiceProvider)
      .watchIsFollowing(key.uid, key.farmerId);
});

final addToCartProvider =
    StateNotifierProvider.autoDispose<AddToCartNotifier, bool>((ref) {
  return AddToCartNotifier(ref.watch(cartServiceProvider));
});

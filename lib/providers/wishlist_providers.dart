import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_logger.dart';
import '../models/product_model.dart';
import 'service_providers.dart';

class WishlistEntry {
  final String productId;
  final ProductModel? product;
  final String? categoryName;
  final String? farmName;

  const WishlistEntry({
    required this.productId,
    required this.product,
    this.categoryName,
    this.farmName,
  });
}

final wishlistIdsProvider =
    StreamProvider.autoDispose.family<List<String>, String>((ref, uid) {
  return ref.watch(wishlistServiceProvider).watchWishlist(uid);
});

final wishlistEntriesProvider = FutureProvider.autoDispose
    .family<List<WishlistEntry>, String>((ref, uid) async {
  final productIds = await ref.watch(wishlistIdsProvider(uid).future);
  final productService = ref.watch(productServiceProvider);
  final products = await Future.wait(productIds.map(productService.getById));

  var categoryNames = <String, String>{};
  final farmNames = <String, String>{};
  try {
    categoryNames = await ref.watch(categoryServiceProvider).getNameMap();
    final farmerService = ref.watch(farmerServiceProvider);
    for (final product in products) {
      if (product == null || farmNames.containsKey(product.farmerId)) continue;
      final farmer = await farmerService.getById(product.farmerId);
      if (farmer != null) farmNames[product.farmerId] = farmer.businessName;
    }
  } catch (e, stack) {
    AppLogger.error('Wishlist label lookup failed', e, stack);
  }

  final entries = <WishlistEntry>[];
  for (var i = 0; i < productIds.length; i++) {
    final product = products[i];
    entries.add(WishlistEntry(
      productId: productIds[i],
      product: product,
      categoryName: product == null ? null : categoryNames[product.categoryId],
      farmName: product == null ? null : farmNames[product.farmerId],
    ));
  }
  return entries;
});

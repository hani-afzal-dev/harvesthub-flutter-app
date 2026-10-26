import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item.dart';
import '../models/product_model.dart';
import 'pickup_providers.dart';
import 'service_providers.dart';

final cartLinesProvider =
    StreamProvider.autoDispose.family<List<CartLine>, String>((ref, uid) {
  return ref.watch(cartServiceProvider).watchCartLines(uid);
});

List<String> _splitIds(String farmerIdsKey) {
  final ids = <String>[];
  for (final id in farmerIdsKey.split(',')) {
    if (id.isNotEmpty) ids.add(id);
  }
  return ids;
}

final earliestPickupProvider = Provider.autoDispose
    .family<AsyncValue<DateTime?>, String>((ref, farmerIdsKey) {
  DateTime? earliest;
  var stillLoading = false;
  Object? firstError;

  for (final farmerId in _splitIds(farmerIdsKey)) {
    final slots = ref.watch(availableSlotsProvider(farmerId));
    if (slots.hasError) {
      firstError ??= slots.error;
      continue;
    }
    final list = slots.valueOrNull;
    if (list == null) {
      stillLoading = true;
      continue;
    }
    if (list.isNotEmpty &&
        (earliest == null || list.first.slotTime.isBefore(earliest))) {
      earliest = list.first.slotTime;
    }
  }

  if (earliest != null) return AsyncValue.data(earliest);
  if (stillLoading) return const AsyncValue.loading();
  if (firstError != null) {
    return AsyncValue.error(firstError, StackTrace.current);
  }
  return const AsyncValue.data(null);
});

final farmerShopProductsProvider = StreamProvider.autoDispose
    .family<List<ProductModel>, String>((ref, farmerId) {
  return ref.watch(productServiceProvider).watchAvailableByFarmer(farmerId);
});

final cartSuggestionsProvider = Provider.autoDispose
    .family<AsyncValue<List<ProductModel>>, String>((ref, farmerIdsKey) {
  final suggestions = <ProductModel>[];
  var stillLoading = false;
  Object? firstError;

  for (final farmerId in _splitIds(farmerIdsKey)) {
    final products = ref.watch(farmerShopProductsProvider(farmerId));
    if (products.hasError) {
      firstError ??= products.error;
      continue;
    }
    final list = products.valueOrNull;
    if (list == null) {
      stillLoading = true;
      continue;
    }
    for (final product in list) {
      if (product.canBeOrdered) suggestions.add(product);
    }
  }

  if (stillLoading && suggestions.isEmpty) return const AsyncValue.loading();
  if (firstError != null && suggestions.isEmpty) {
    return AsyncValue.error(firstError, StackTrace.current);
  }
  return AsyncValue.data(suggestions);
});

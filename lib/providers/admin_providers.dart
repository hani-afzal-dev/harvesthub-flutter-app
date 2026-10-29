import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../models/category_model.dart';
import '../models/farmer_model.dart';
import '../models/market_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';
import '../services/admin_service.dart';
import 'service_providers.dart';

final adminDashboardStatsProvider =
    FutureProvider.autoDispose<AdminDashboardStats>((ref) {
  return ref.watch(adminServiceProvider).loadDashboardStats();
});

final adminUsersByRoleProvider =
    StreamProvider.autoDispose.family<List<UserModel>, UserRole>((ref, role) {
  return ref.watch(adminServiceProvider).watchUsersByRole(role);
});

final adminFarmerProfilesProvider =
    StreamProvider.autoDispose<List<FarmerModel>>((ref) {
  return ref.watch(adminServiceProvider).watchAllFarmers();
});

final adminOrderLimitProvider =
    StateProvider.autoDispose<int>((ref) => PagingRules.pageSize);

final adminOrdersProvider = StreamProvider.autoDispose<List<OrderModel>>((ref) {
  final limit = ref.watch(adminOrderLimitProvider);
  return ref.watch(adminServiceProvider).watchAllOrders(limit: limit);
});

final adminAllMarketsProvider =
    StreamProvider.autoDispose<List<MarketModel>>((ref) {
  return ref.watch(marketServiceProvider).watchAllMarkets();
});

final adminMarketsProvider =
    FutureProvider.autoDispose<List<MarketModel>>((ref) {
  return ref.watch(marketServiceProvider).getActiveMarkets();
});

final adminProductsProvider =
    StreamProvider.autoDispose<List<ProductModel>>((ref) {
  return ref
      .watch(productServiceProvider)
      .watchAllProducts(limit: 200, availableOnly: false);
});

final adminCategoriesProvider =
    StreamProvider.autoDispose<List<CategoryModel>>((ref) {
  return ref.watch(categoryServiceProvider).watchCategories();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/report_model.dart';
import 'service_providers.dart';

final farmerProductsProvider = StreamProvider.autoDispose
    .family<List<ProductModel>, String>((ref, farmerId) {
  return ref.watch(productServiceProvider).watchByFarmer(farmerId);
});

final farmerOrderLimitProvider =
    StateProvider.autoDispose.family<int, String>((ref, farmerId) {
  return PagingRules.pageSize;
});

final farmerOrdersProvider = StreamProvider.autoDispose
    .family<List<OrderModel>, String>((ref, farmerId) {
  final limit = ref.watch(farmerOrderLimitProvider(farmerId));
  return ref
      .watch(orderServiceProvider)
      .watchFarmerOrders(farmerId, limit: limit);
});

final farmerReportsProvider = StreamProvider.autoDispose
    .family<List<ReportModel>, String>((ref, farmerId) {
  return ref.watch(reportServiceProvider).watchReports(farmerId);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../models/order_model.dart';
import 'service_providers.dart';

final customerOrderStatusFilterProvider =
    StateProvider.autoDispose.family<String?, String>((ref, uid) => null);

final customerOrderLimitProvider =
    StateProvider.autoDispose.family<int, String>((ref, uid) {
  ref.watch(customerOrderStatusFilterProvider(uid));
  return PagingRules.pageSize;
});

final customerOrdersProvider =
    StreamProvider.autoDispose.family<List<OrderModel>, String>((ref, uid) {
  final limit = ref.watch(customerOrderLimitProvider(uid));
  final status = ref.watch(customerOrderStatusFilterProvider(uid));
  return ref
      .watch(orderServiceProvider)
      .watchCustomerOrders(uid, limit: limit, status: status);
});

final customerOrderCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, uid) {
  ref.watch(customerOrdersProvider(uid));
  return ref.watch(orderServiceProvider).countCustomerOrders(uid);
});

final cachedCustomerOrdersProvider =
    FutureProvider.autoDispose.family<List<OrderModel>, String>((ref, uid) {
  return ref.watch(orderServiceProvider).getCachedCustomerOrders(uid);
});

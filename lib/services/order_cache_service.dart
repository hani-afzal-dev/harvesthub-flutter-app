import 'dart:convert';
import '../core/app_logger.dart';
import '../core/local_db.dart';
import '../models/order_model.dart';

class OrderCacheService {
  Future<void> cacheOrders(String customerId, List<OrderModel> orders) async {
    try {
      final db = await LocalDb.instance;
      final now = DateTime.now().millisecondsSinceEpoch;

      final batch = db.batch();
      batch.delete('orders_cache',
          where: 'customerId = ?', whereArgs: [customerId]);
      for (final order in orders) {
        batch.insert('orders_cache', {
          'orderId': order.orderId,
          'customerId': order.customerId,
          'farmerId': order.farmerId,
          'itemsJson':
              jsonEncode(order.items.map((item) => item.toMap()).toList()),
          'totalPrice': order.totalPrice,
          'promoCode': order.promoCode,
          'discount': order.discount,
          'status': orderStatusToString(order.status),
          'pickupSlotId': order.pickupSlotId,
          'pickupSlotTime': order.pickupSlotTime?.millisecondsSinceEpoch,
          'deliveryAddr': order.deliveryAddr,
          'customerRating': order.customerRating,
          'createdAt': order.createdAt.millisecondsSinceEpoch,
          'updatedAt': order.updatedAt.millisecondsSinceEpoch,
          'cachedAt': now,
        });
      }
      await batch.commit(noResult: true);
    } catch (e, stack) {
      AppLogger.error('Order cache write failed', e, stack);
    }
  }

  Future<List<OrderModel>> getCachedOrders(String customerId) async {
    try {
      final db = await LocalDb.instance;
      final rows = await db.query(
        'orders_cache',
        where: 'customerId = ?',
        whereArgs: [customerId],
        orderBy: 'createdAt DESC',
      );
      return rows.map(_fromRow).toList();
    } catch (e, stack) {
      AppLogger.error('Order cache read failed', e, stack);
      return [];
    }
  }

  OrderModel _fromRow(Map<String, Object?> row) {
    final rawItems = jsonDecode(row['itemsJson'] as String) as List;
    final pickupMillis = row['pickupSlotTime'] as int?;
    return OrderModel(
      orderId: row['orderId'] as String,
      customerId: row['customerId'] as String,
      farmerId: row['farmerId'] as String,
      items: rawItems
          .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      totalPrice: (row['totalPrice'] as num).toDouble(),
      promoCode: row['promoCode'] as String?,
      discount: ((row['discount'] as num?) ?? 0).toDouble(),
      status: orderStatusFromString(row['status'] as String),
      pickupSlotId: row['pickupSlotId'] as String?,
      pickupSlotTime: pickupMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(pickupMillis),
      deliveryAddr: row['deliveryAddr'] as String,
      customerRating: row['customerRating'] as int?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updatedAt'] as int),
    );
  }
}

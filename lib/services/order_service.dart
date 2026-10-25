import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/app_logger.dart';
import '../core/background_task.dart';
import '../core/constants.dart';
import '../models/cart_item.dart';
import '../models/notification_model.dart';
import '../models/order_model.dart';
import '../models/promo_code_model.dart';
import 'notification_service.dart';
import 'order_cache_service.dart';
import 'promo_service.dart';

class InsufficientStockException implements Exception {
  final String itemName;
  final String productId;
  final int available;
  final String unit;
  InsufficientStockException(this.itemName, this.productId,
      {this.available = 0, this.unit = ''});

  @override
  String toString() => available > 0
      ? 'Only $available $unit of $itemName is left. Your cart was updated to $available.'
      : 'Sorry, $itemName just ran out of stock. It has been removed from your cart.';
}

class PriceChangedException implements Exception {
  final String itemName;
  PriceChangedException(this.itemName);

  @override
  String toString() =>
      'The price of $itemName just changed. Check your cart and place the order again.';
}

class TooManyItemsException implements Exception {
  final int limit;
  TooManyItemsException(this.limit);

  @override
  String toString() =>
      'One order can have up to $limit different products from the same farm. Remove a few and order them separately.';
}

class SlotFullDuringCheckoutException implements Exception {
  @override
  String toString() => 'Slot no longer available.';
}

class OrderNotEditableException implements Exception {
  @override
  String toString() => 'This order can no longer be changed.';
}

class RatingNotAllowedException implements Exception {
  @override
  String toString() => 'This order cannot be rated.';
}

class PickupSelection {
  final String slotId;
  final DateTime slotTime;
  PickupSelection({required this.slotId, required this.slotTime});
}

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final OrderCacheService _orderCache = OrderCacheService();

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection(FirestoreCollections.orders);

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection(FirestoreCollections.products);

  CollectionReference<Map<String, dynamic>> get _cartItems =>
      _firestore.collection(FirestoreCollections.cartItems);

  CollectionReference<Map<String, dynamic>> get _slots =>
      _firestore.collection(FirestoreCollections.pickupSlots);

  CollectionReference<Map<String, dynamic>> get _farmers =>
      _firestore.collection(FirestoreCollections.farmers);

  Future<List<String>> placeOrder({
    required String customerId,
    required String customerName,
    required List<CartLine> lines,
    required String deliveryAddr,
    Map<String, PickupSelection>? pickupSelections,
    String? promoCode,
  }) async {
    final byFarmer = <String, List<CartLine>>{};
    final farmerSubtotals = <String, double>{};
    final orderRefs = <String, DocumentReference<Map<String, dynamic>>>{};
    var cartSubtotal = 0.0;
    for (final line in lines) {
      byFarmer.putIfAbsent(line.farmerId, () => []).add(line);
      farmerSubtotals[line.farmerId] =
          (farmerSubtotals[line.farmerId] ?? 0) + line.lineTotal;
      orderRefs.putIfAbsent(line.farmerId, () => _orders.doc());
      cartSubtotal += line.lineTotal;
    }

    for (final farmerLines in byFarmer.values) {
      if (farmerLines.length > OrderRules.maxItemsPerOrder) {
        throw TooManyItemsException(OrderRules.maxItemsPerOrder);
      }
    }

    var discountSplits = <String, double>{};
    final farmerIds = byFarmer.keys.toList();

    Future<String> placeForFarmer(String farmerId, bool redeemPromo) async {
      final farmerLines = byFarmer[farmerId]!;
      final orderRef = orderRefs[farmerId]!;
      final selection = pickupSelections?[farmerId];
      var lowStock = <MapEntry<CartLine, int>>[];

      await _firestore.runTransaction((tx) async {
        Future<DocumentSnapshot<Map<String, dynamic>>> readProduct(
            CartLine line) async {
          try {
            return await tx.get(_products.doc(line.productId));
          } on FirebaseException catch (e) {
            if (e.code != 'permission-denied') rethrow;
            throw InsufficientStockException(line.itemName, line.productId);
          }
        }

        final redemptionRef = _firestore
            .collection(FirestoreCollections.promoRedemptions)
            .doc(PromoService.redemptionId(customerId, promoCode ?? ''));

        final productsRead = Future.wait(farmerLines.map(readProduct));
        final slotRead = selection == null
            ? Future<DocumentSnapshot<Map<String, dynamic>>?>.value(null)
            : tx.get(_slots.doc(selection.slotId));
        final promoRead = redeemPromo
            ? tx.get(_firestore
                .collection(FirestoreCollections.promoCodes)
                .doc(promoCode))
            : Future<DocumentSnapshot<Map<String, dynamic>>?>.value(null);
        final usedRead = redeemPromo
            ? tx.get(redemptionRef)
            : Future<DocumentSnapshot<Map<String, dynamic>>?>.value(null);
        await Future.wait<Object?>(
            [productsRead, slotRead, promoRead, usedRead]);

        final productList = await productsRead;
        final productSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (var i = 0; i < farmerLines.length; i++) {
          productSnaps[farmerLines[i].productId] = productList[i];
        }
        final slotSnap = await slotRead;

        Map<String, dynamic>? redemption;
        if (redeemPromo) {
          final promoSnap = (await promoRead)!;
          final usedSnap = (await usedRead)!;
          final splits = _splitDiscount(
            promoSnap: promoSnap,
            alreadyUsed: usedSnap.exists,
            cartSubtotal: cartSubtotal,
            farmerSubtotals: farmerSubtotals,
            orderRefs: orderRefs,
          );
          var redeemed = 0.0;
          for (final amount in splits.values) {
            redeemed += amount;
          }
          discountSplits = splits;
          redemption = {
            'customerId': customerId,
            'code': promoCode,
            'discount': redeemed,
            'splits': splits,
            'redeemedAt': FieldValue.serverTimestamp(),
          };
        }

        final crossedThreshold = <MapEntry<CartLine, int>>[];
        for (final line in farmerLines) {
          final data = productSnaps[line.productId]!.data();
          final currentStock = ((data?['stockQty'] ?? 0) as num).toInt();
          final available = data != null && data['isAvailable'] == true;
          if (!available || currentStock < line.quantity) {
            throw InsufficientStockException(line.itemName, line.productId,
                available: available ? currentStock : 0,
                unit: line.product?.unit ?? '');
          }
          final currentPrice = ((data['pricePerUnit'] ?? 0) as num).toDouble();
          if ((currentPrice - line.pricePerUnit).abs() > 0.001) {
            throw PriceChangedException(line.itemName);
          }
          final remaining = currentStock - line.quantity;
          if (currentStock > StockRules.lowStockThreshold &&
              remaining <= StockRules.lowStockThreshold) {
            crossedThreshold.add(MapEntry(line, remaining));
          }
        }

        if (slotSnap != null) {
          final slotData = slotSnap.data();
          final capacity = ((slotData?['capacity'] ?? 0) as num).toInt();
          final booked = ((slotData?['booked'] ?? 0) as num).toInt();
          final active = slotData != null && slotData['isActive'] == true;
          if (!active || booked >= capacity) {
            throw SlotFullDuringCheckoutException();
          }
        }

        for (final line in farmerLines) {
          tx.update(_products.doc(line.productId), {
            'stockQty': FieldValue.increment(-line.quantity),
          });
          tx.delete(_cartItems.doc('${customerId}_${line.productId}'));
        }

        if (slotSnap != null) {
          tx.update(_slots.doc(selection!.slotId),
              {'booked': FieldValue.increment(1)});
        }

        final orderItems = farmerLines
            .map((line) => OrderItem(
                  productId: line.productId,
                  itemName: line.itemName,
                  qty: line.quantity,
                  pricePerUnit: line.pricePerUnit,
                  subtotal: line.lineTotal,
                ))
            .toList();

        var total = 0.0;
        for (final item in orderItems) {
          total += item.subtotal;
        }
        final orderDiscount = discountSplits[orderRef.id] ?? 0;

        final order = OrderModel(
          orderId: orderRef.id,
          customerId: customerId,
          customerName: customerName,
          farmerId: farmerId,
          items: orderItems,
          totalPrice: total,
          promoCode: orderDiscount > 0 ? promoCode : null,
          discount: orderDiscount,
          status: OrderStatus.pending,
          pickupSlotId: selection?.slotId,
          pickupSlotTime: selection?.slotTime,
          deliveryAddr: deliveryAddr,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        if (redemption != null) tx.set(redemptionRef, redemption);
        tx.set(orderRef, order.toCreateMap());
        lowStock = crossedThreshold;
      });

      final lowStockAlerts = lowStock;
      runInBackground('Order notifications failed', () async {
        await _notificationService.send(
          userId: farmerId,
          type: NotificationType.newOrder,
          message: customerName.isEmpty
              ? 'You have a new customer order to review.'
              : 'You have a new order from $customerName.',
          relatedId: orderRef.id,
          docId: 'new_order_${orderRef.id}',
        );
        for (final low in lowStockAlerts) {
          await _notificationService.send(
            userId: farmerId,
            type: NotificationType.restockAlert,
            message: '${low.key.itemName} is running low: ${low.value} left.',
            relatedId: low.key.productId,
          );
        }
      });
      return orderRef.id;
    }

    if (farmerIds.isEmpty) return const [];
    final firstId = await placeForFarmer(farmerIds.first, promoCode != null);
    final otherIds = await Future.wait(
        farmerIds.skip(1).map((farmerId) => placeForFarmer(farmerId, false)));
    return [firstId, ...otherIds];
  }

  Map<String, double> _splitDiscount({
    required DocumentSnapshot<Map<String, dynamic>> promoSnap,
    required bool alreadyUsed,
    required double cartSubtotal,
    required Map<String, double> farmerSubtotals,
    required Map<String, DocumentReference<Map<String, dynamic>>> orderRefs,
  }) {
    final data = promoSnap.data();
    if (data == null) {
      throw PromoCodeException('This promo code is no longer available.');
    }
    if (alreadyUsed) {
      throw PromoCodeException('You have already used ${promoSnap.id}.');
    }

    final promo = PromoCodeModel.fromMap(promoSnap.id, data);
    if (!promo.isUsableAt(DateTime.now())) {
      throw PromoCodeException('This promo code has expired.');
    }
    final discount = promo.discountFor(cartSubtotal);
    if (discount <= 0) {
      throw PromoCodeException(
          'Your cart no longer qualifies for ${promo.code}.');
    }

    final splits = <String, double>{};
    final farmerIds = farmerSubtotals.keys.toList();
    var remaining = discount;
    for (var i = 0; i < farmerIds.length; i++) {
      final farmerSubtotal = farmerSubtotals[farmerIds[i]]!;
      var share = (discount * farmerSubtotal / cartSubtotal).floorToDouble();
      if (i == farmerIds.length - 1) share = remaining;
      if (share > farmerSubtotal) share = farmerSubtotal;
      remaining -= share;
      if (share > 0) splits[orderRefs[farmerIds[i]]!.id] = share;
    }
    return splits;
  }

  Stream<List<OrderModel>> watchCustomerOrders(String customerId,
      {int limit = PagingRules.pageSize, String? status}) {
    final byCustomer = _orders.where('customerId', isEqualTo: customerId);
    if (status == null) {
      return byCustomer
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) {
        final orders = _toOrders(snap);
        _orderCache.cacheOrders(customerId, orders);
        return orders;
      });
    }
    return _watchCustomerOrdersByStatus(byCustomer, status, limit);
  }

  Stream<List<OrderModel>> _watchCustomerOrdersByStatus(
    Query<Map<String, dynamic>> byCustomer,
    String status,
    int limit,
  ) async* {
    final filtered = byCustomer
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    try {
      await for (final snap in filtered.snapshots()) {
        yield _toOrders(snap);
      }
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;
      AppLogger.info('Order status index not ready, filtering on device');
      final recent =
          byCustomer.orderBy('createdAt', descending: true).limit(limit * 5);
      await for (final snap in recent.snapshots()) {
        final matching = <OrderModel>[];
        for (final order in _toOrders(snap)) {
          if (orderStatusToString(order.status) == status) matching.add(order);
          if (matching.length == limit) break;
        }
        yield matching;
      }
    }
  }

  List<OrderModel> _toOrders(QuerySnapshot<Map<String, dynamic>> snap) {
    return snap.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList();
  }

  Future<int> countCustomerOrders(String customerId) async {
    final snap =
        await _orders.where('customerId', isEqualTo: customerId).count().get();
    return snap.count ?? 0;
  }

  Future<List<OrderModel>> getCachedCustomerOrders(String customerId) {
    return _orderCache.getCachedOrders(customerId);
  }

  Stream<List<OrderModel>> watchFarmerOrders(String farmerId,
      {int limit = PagingRules.pageSize}) {
    return _orders
        .where('farmerId', isEqualTo: farmerId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList());
  }

  Future<OrderModel> _loadOrder(String orderId) async {
    final doc = await _orders.doc(orderId).get();
    final data = doc.data();
    if (data == null) {
      throw OrderNotEditableException();
    }
    return OrderModel.fromMap(doc.id, data);
  }

  Future<void> _cancelWithRestock(
      OrderModel order, Map<String, dynamic> statusChanges) async {
    await _firestore.runTransaction((tx) async {
      final restorable = <OrderItem>[];
      for (final item in order.items) {
        try {
          final snap = await tx.get(_products.doc(item.productId));
          if (snap.exists) restorable.add(item);
        } on FirebaseException catch (e) {
          if (e.code != 'permission-denied') rethrow;
        }
      }

      DocumentSnapshot<Map<String, dynamic>>? slotSnap;
      final slotId = order.pickupSlotId;
      if (slotId != null) {
        slotSnap = await tx.get(_slots.doc(slotId));
      }

      for (final item in restorable) {
        tx.update(_products.doc(item.productId), {
          'stockQty': FieldValue.increment(item.qty),
          'lastRestockOrderId': order.orderId,
        });
      }

      if (slotSnap != null && slotSnap.exists) {
        final booked = ((slotSnap.data()?['booked'] ?? 0) as num).toInt();
        if (booked > 0) {
          tx.update(slotSnap.reference, {'booked': FieldValue.increment(-1)});
        }
      }

      tx.update(_orders.doc(order.orderId), statusChanges);
    });
  }

  Future<void> updateStatus(String orderId, OrderStatus status) async {
    final order = await _loadOrder(orderId);
    final statusChanges = {
      'status': orderStatusToString(status),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (status == OrderStatus.cancelled &&
        order.status != OrderStatus.cancelled) {
      await _cancelWithRestock(order, statusChanges);
    } else {
      await _orders.doc(orderId).update(statusChanges);
    }

    runInBackground(
        'Notification failed',
        () => _notificationService.send(
              userId: order.customerId,
              type: NotificationType.orderStatus,
              message: 'Your order is now ${_statusLabel(status)}.',
              relatedId: orderId,
            ));
  }

  Future<void> cancelOrder(String orderId) async {
    await updateStatus(orderId, OrderStatus.cancelled);
  }

  Future<void> cancelOwnOrder(String orderId) async {
    final order = await _loadOrder(orderId);
    if (order.status != OrderStatus.pending &&
        order.status != OrderStatus.confirmed) {
      throw OrderNotEditableException();
    }

    await _cancelWithRestock(order, {
      'status': OrderStatusValues.cancelled,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    runInBackground(
        'Notification failed',
        () => _notificationService.send(
              userId: order.farmerId,
              type: NotificationType.bookingModified,
              message: 'A customer cancelled an order.',
              relatedId: orderId,
            ));
  }

  Future<void> modifyPickupSlot({
    required String orderId,
    required String newSlotId,
  }) async {
    final orderRef = _orders.doc(orderId);
    var farmerId = '';

    await _firestore.runTransaction((tx) async {
      final orderSnap = await tx.get(orderRef);
      final orderData = orderSnap.data();
      if (orderData == null) throw OrderNotEditableException();
      final order = OrderModel.fromMap(orderSnap.id, orderData);
      if (order.status != OrderStatus.pending &&
          order.status != OrderStatus.confirmed) {
        throw OrderNotEditableException();
      }
      if (order.pickupSlotId == newSlotId) return;

      final newSlotRef = _slots.doc(newSlotId);
      final newSnap = await tx.get(newSlotRef);
      final newData = newSnap.data();
      if (newData == null) throw SlotFullDuringCheckoutException();
      final capacity = ((newData['capacity'] ?? 0) as num).toInt();
      final booked = ((newData['booked'] ?? 0) as num).toInt();
      final usable = newData['isActive'] == true &&
          newData['farmerId'] == order.farmerId &&
          booked < capacity;
      if (!usable) throw SlotFullDuringCheckoutException();

      DocumentSnapshot<Map<String, dynamic>>? oldSnap;
      final oldSlotId = order.pickupSlotId;
      if (oldSlotId != null) {
        oldSnap = await tx.get(_slots.doc(oldSlotId));
      }

      tx.update(newSlotRef, {'booked': FieldValue.increment(1)});
      if (oldSnap != null && oldSnap.exists) {
        final oldBooked = ((oldSnap.data()?['booked'] ?? 0) as num).toInt();
        if (oldBooked > 0) {
          tx.update(oldSnap.reference, {'booked': FieldValue.increment(-1)});
        }
      }

      tx.update(orderRef, {
        'pickupSlotId': newSlotId,
        'pickupSlotTime': newData['slotTime'],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      farmerId = order.farmerId;
    });

    if (farmerId.isEmpty) return;
    runInBackground(
        'Notification failed',
        () => _notificationService.send(
              userId: farmerId,
              type: NotificationType.bookingModified,
              message: 'A customer changed the pickup time for an order.',
              relatedId: orderId,
            ));
  }

  Future<void> submitRating(
      {required String orderId, required int stars}) async {
    if (stars < 1 || stars > 5) {
      throw RatingNotAllowedException();
    }
    final orderRef = _orders.doc(orderId);

    await _firestore.runTransaction((tx) async {
      final orderSnap = await tx.get(orderRef);
      final orderData = orderSnap.data();
      if (orderData == null) throw RatingNotAllowedException();
      final order = OrderModel.fromMap(orderSnap.id, orderData);
      if (order.status != OrderStatus.completed ||
          order.customerRating != null) {
        throw RatingNotAllowedException();
      }

      final farmerRef = _farmers.doc(order.farmerId);
      final farmerSnap = await tx.get(farmerRef);
      final farmerData = farmerSnap.data();
      if (farmerData == null) throw RatingNotAllowedException();

      final previousSum = ((farmerData['ratingSum'] ?? 0) as num).toInt();
      final previousCount = ((farmerData['ratingCount'] ?? 0) as num).toInt();
      final newSum = previousSum + stars;
      final newCount = previousCount + 1;

      tx.update(orderRef, {'customerRating': stars});
      tx.update(farmerRef, {
        'ratingSum': newSum,
        'ratingCount': newCount,
        'rating': newSum / newCount,
        'lastRatedOrderId': orderId,
      });
    });
  }

  String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.readyForPickup:
        return 'ready for pickup';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
      case OrderStatus.pending:
        return 'pending';
    }
  }
}

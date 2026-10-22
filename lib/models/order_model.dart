import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

enum OrderStatus { pending, confirmed, readyForPickup, completed, cancelled }

OrderStatus orderStatusFromString(String value) {
  switch (value) {
    case OrderStatusValues.confirmed:
      return OrderStatus.confirmed;
    case OrderStatusValues.readyForPickup:
      return OrderStatus.readyForPickup;
    case OrderStatusValues.completed:
      return OrderStatus.completed;
    case OrderStatusValues.cancelled:
      return OrderStatus.cancelled;
    default:
      return OrderStatus.pending;
  }
}

String orderStatusToString(OrderStatus status) {
  switch (status) {
    case OrderStatus.confirmed:
      return OrderStatusValues.confirmed;
    case OrderStatus.readyForPickup:
      return OrderStatusValues.readyForPickup;
    case OrderStatus.completed:
      return OrderStatusValues.completed;
    case OrderStatus.cancelled:
      return OrderStatusValues.cancelled;
    case OrderStatus.pending:
      return OrderStatusValues.pending;
  }
}

class OrderItem {
  final String productId;
  final String itemName;
  final int qty;
  final double pricePerUnit;
  final double subtotal;

  OrderItem({
    required this.productId,
    required this.itemName,
    required this.qty,
    required this.pricePerUnit,
    required this.subtotal,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      itemName: map['itemName'] ?? '',
      qty: ((map['qty'] ?? 0) as num).toInt(),
      pricePerUnit: (map['pricePerUnit'] ?? 0).toDouble(),
      subtotal: (map['subtotal'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'itemName': itemName,
      'qty': qty,
      'pricePerUnit': pricePerUnit,
      'subtotal': subtotal,
    };
  }
}

class OrderModel {
  final String orderId;
  final String customerId;
  final String customerName;
  final String farmerId;
  final List<OrderItem> items;
  final double totalPrice;
  final String? promoCode;
  final double discount;
  final OrderStatus status;
  final String? pickupSlotId;
  final DateTime? pickupSlotTime;
  final String deliveryAddr;
  final int? customerRating;
  final DateTime createdAt;
  final DateTime updatedAt;

  OrderModel({
    required this.orderId,
    required this.customerId,
    this.customerName = '',
    required this.farmerId,
    required this.items,
    required this.totalPrice,
    this.promoCode,
    this.discount = 0,
    required this.status,
    this.pickupSlotId,
    this.pickupSlotTime,
    required this.deliveryAddr,
    this.customerRating,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderModel.fromMap(String id, Map<String, dynamic> map) {
    final rawItems = (map['items'] as List?) ?? [];
    final createdAt =
        (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return OrderModel(
      orderId: id,
      customerId: map['customerId'] ?? '',
      customerName: (map['customerName'] ?? '').toString(),
      farmerId: map['farmerId'] ?? '',
      items: rawItems
          .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      totalPrice: (map['totalPrice'] ?? 0).toDouble(),
      promoCode: map['promoCode'] as String?,
      discount: ((map['discount'] ?? 0) as num).toDouble(),
      status: orderStatusFromString(map['status'] ?? OrderStatusValues.pending),
      pickupSlotId: map['pickupSlotId'] as String?,
      pickupSlotTime: (map['pickupSlotTime'] as Timestamp?)?.toDate(),
      deliveryAddr: map['deliveryAddr'] ?? '',
      customerRating: (map['customerRating'] as num?)?.toInt(),
      createdAt: createdAt,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? createdAt,
    );
  }

  bool get hasDiscount => discount > 0;

  double get amountPayable => totalPrice - discount;

  Map<String, dynamic> toCreateMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'farmerId': farmerId,
      'items': items.map((e) => e.toMap()).toList(),
      'totalPrice': totalPrice,
      'promoCode': promoCode,
      'discount': discount,
      'status': orderStatusToString(status),
      'pickupSlotId': pickupSlotId,
      'pickupSlotTime':
          pickupSlotTime != null ? Timestamp.fromDate(pickupSlotTime!) : null,
      'deliveryAddr': deliveryAddr,
      'customerRating': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

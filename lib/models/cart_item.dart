import 'package:cloud_firestore/cloud_firestore.dart';
import 'product_model.dart';

class CartItem {
  final String cartItemId;
  final String customerId;
  final String productId;
  final int quantity;
  final DateTime addedAt;

  CartItem({
    required this.cartItemId,
    required this.customerId,
    required this.productId,
    required this.quantity,
    required this.addedAt,
  });

  factory CartItem.fromMap(String id, Map<String, dynamic> map) {
    return CartItem(
      cartItemId: id,
      customerId: map['customerId'] ?? '',
      productId: map['productId'] ?? '',
      quantity: ((map['quantity'] ?? 0) as num).toInt(),
      addedAt: (map['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'productId': productId,
      'quantity': quantity,
      'addedAt': FieldValue.serverTimestamp(),
    };
  }
}

class CartLine {
  final CartItem item;
  final ProductModel? product;

  CartLine({required this.item, required this.product});

  String get productId => item.productId;
  int get quantity => item.quantity;
  bool get isAvailable => product != null && product!.isAvailable;
  String get itemName => product?.itemName ?? 'Unavailable item';
  double get pricePerUnit => product?.pricePerUnit ?? 0;
  String get farmerId => product?.farmerId ?? '';
  double get lineTotal => isAvailable ? pricePerUnit * quantity : 0;
}

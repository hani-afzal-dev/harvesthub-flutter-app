import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String productId;
  final String farmerId;
  final String categoryId;
  final String itemName;
  final String description;
  final double pricePerUnit;
  final String unit;
  final int stockQty;
  final String? imageUrl;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductModel({
    required this.productId,
    required this.farmerId,
    required this.categoryId,
    required this.itemName,
    this.description = '',
    required this.pricePerUnit,
    required this.unit,
    required this.stockQty,
    this.imageUrl,
    this.isAvailable = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get inStock => stockQty > 0;
  bool get canBeOrdered => isAvailable && stockQty > 0;

  bool get hasImage {
    final url = imageUrl;
    return url != null && url.isNotEmpty;
  }

  factory ProductModel.fromMap(String id, Map<String, dynamic> map) {
    return ProductModel(
      productId: id,
      farmerId: map['farmerId'] ?? '',
      categoryId: map['categoryId'] ?? '',
      itemName: map['itemName'] ?? '',
      description: map['description'] ?? '',
      pricePerUnit: (map['pricePerUnit'] ?? 0).toDouble(),
      unit: map['unit'] ?? 'kg',
      stockQty: ((map['stockQty'] ?? 0) as num).toInt(),
      imageUrl: map['imageUrl'] as String?,
      isAvailable: map['isAvailable'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'farmerId': farmerId,
      'categoryId': categoryId,
      'itemName': itemName,
      'itemNameLower': itemName.toLowerCase(),
      'description': description,
      'pricePerUnit': pricePerUnit,
      'unit': unit,
      'stockQty': stockQty,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'categoryId': categoryId,
      'itemName': itemName,
      'itemNameLower': itemName.toLowerCase(),
      'description': description,
      'pricePerUnit': pricePerUnit,
      'unit': unit,
      'stockQty': stockQty,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

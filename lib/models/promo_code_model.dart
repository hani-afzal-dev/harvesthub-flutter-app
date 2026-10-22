import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

class PromoCodeModel {
  final String code;
  final String type;
  final double value;
  final double minOrder;
  final double maxDiscount;
  final bool active;
  final DateTime expiresAt;
  final DateTime createdAt;

  PromoCodeModel({
    required this.code,
    required this.type,
    required this.value,
    required this.minOrder,
    required this.maxDiscount,
    required this.active,
    required this.expiresAt,
    required this.createdAt,
  });

  bool get isPercent => type == PromoTypes.percent;

  bool isUsableAt(DateTime now) => active && expiresAt.isAfter(now);

  String get shortLabel {
    if (isPercent) {
      return '${value.toStringAsFixed(0)}% off, up to Rs. ${maxDiscount.toStringAsFixed(0)}';
    }
    return 'Rs. ${value.toStringAsFixed(0)} off';
  }

  double discountFor(double subtotal) {
    if (subtotal <= 0 || subtotal < minOrder) return 0;
    double discount;
    if (isPercent) {
      discount = subtotal * value / 100;
      if (discount > maxDiscount) discount = maxDiscount;
    } else {
      discount = value;
    }
    if (discount > subtotal) discount = subtotal;
    return discount.floorToDouble();
  }

  factory PromoCodeModel.fromMap(String id, Map<String, dynamic> map) {
    final created =
        (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return PromoCodeModel(
      code: map['code'] ?? id,
      type:
          map['type'] == PromoTypes.flat ? PromoTypes.flat : PromoTypes.percent,
      value: ((map['value'] ?? 0) as num).toDouble(),
      minOrder: ((map['minOrder'] ?? 0) as num).toDouble(),
      maxDiscount: ((map['maxDiscount'] ?? 0) as num).toDouble(),
      active: map['active'] == true,
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate() ?? created,
      createdAt: created,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'code': code,
      'type': type,
      'value': value,
      'minOrder': minOrder,
      'maxDiscount': maxDiscount,
      'active': active,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

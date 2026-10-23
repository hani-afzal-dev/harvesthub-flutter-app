import '../core/constants.dart';
import 'category_model.dart';

class VoiceListingDraft {
  final String itemName;
  final String? categoryId;
  final String categoryName;
  final int quantity;
  final String unit;
  final double pricePerUnit;
  final String description;

  const VoiceListingDraft({
    required this.itemName,
    this.categoryId,
    this.categoryName = '',
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
    this.description = '',
  });

  VoiceListingDraft copyWith({
    String? itemName,
    String? categoryId,
    String? categoryName,
    int? quantity,
    String? unit,
    double? pricePerUnit,
    String? description,
  }) {
    return VoiceListingDraft(
      itemName: itemName ?? this.itemName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      description: description ?? this.description,
    );
  }

  static String normalizeUnit(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower == 'kilo' ||
        lower == 'kg' ||
        lower == 'kilos' ||
        lower == 'kilogram' ||
        lower == 'kilograms') {
      return 'kg';
    }
    if (lower == 'litre' ||
        lower == 'liter' ||
        lower == 'litres' ||
        lower == 'liters' ||
        lower == 'l') {
      return 'litre';
    }
    if (lower == 'darjan' ||
        lower == 'dozen' ||
        lower == 'dozens' ||
        lower == 'dz') {
      return 'dozen';
    }
    if (lower == 'piece' ||
        lower == 'dana' ||
        lower == 'number' ||
        lower == 'pieces' ||
        lower == 'pc' ||
        lower == 'pcs' ||
        lower == 'adad' ||
        lower == 'item' ||
        lower == 'items') {
      return 'piece';
    }
    return raw;
  }

  static VoiceListingDraft? fromJsonMap(
    Map<String, dynamic> map,
    List<CategoryModel> categories,
  ) {
    final rawName = map['itemName'];
    if (rawName is! String) return null;
    final name = rawName.trim();
    if (name.length < 2 || name.length > 100) return null;

    final rawQuantity = map['quantity'];
    int? qty;
    if (rawQuantity is num) {
      qty = rawQuantity.toInt();
    } else if (rawQuantity is String) {
      qty = int.tryParse(rawQuantity.trim());
    }
    if (qty == null || qty < 0 || qty > 10000) return null;

    final rawUnit = map['unit'];
    if (rawUnit is! String) return null;
    final unit = normalizeUnit(rawUnit);
    if (!ProductUnits.all.contains(unit)) return null;

    final rawPrice = map['pricePerUnit'];
    double? price;
    if (rawPrice is num) {
      price = rawPrice.toDouble();
    } else if (rawPrice is String) {
      price = double.tryParse(rawPrice.trim());
    }
    if (price == null || price <= 0 || price > 1000000) return null;

    String desc = '';
    final rawDesc = map['description'];
    if (rawDesc is String) {
      desc = rawDesc.trim();
      if (desc.length > 500) {
        desc = desc.substring(0, 500);
      }
    }

    String? matchedCatId;
    String matchedCatName = '';
    final rawCat = map['category'];
    if (rawCat is String && rawCat.trim().isNotEmpty) {
      final catQuery = rawCat.trim().toLowerCase();
      for (final cat in categories) {
        if (cat.name.toLowerCase() == catQuery) {
          matchedCatId = cat.categoryId;
          matchedCatName = cat.name;
          break;
        }
      }
    }

    return VoiceListingDraft(
      itemName: name,
      categoryId: matchedCatId,
      categoryName: matchedCatName,
      quantity: qty,
      unit: unit,
      pricePerUnit: price,
      description: desc,
    );
  }
}

import 'product_model.dart';

class SmartBasketRequestedItem {
  final String name;
  final double quantity;
  final String unit;

  const SmartBasketRequestedItem({
    required this.name,
    required this.quantity,
    this.unit = '',
  });

  static String normalizeUnit(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower == 'kg' || lower == 'kilo' || lower == 'kilos' || lower == 'kilogram') {
      return 'kg';
    }
    if (lower == 'litre' || lower == 'liter' || lower == 'litres' || lower == 'liters' || lower == 'l') {
      return 'litre';
    }
    if (lower == 'dozen' || lower == 'darjan' || lower == 'dozens') {
      return 'dozen';
    }
    if (lower == 'piece' || lower == 'dana' || lower == 'pieces' || lower == 'pc' || lower == 'adad') {
      return 'piece';
    }
    return '';
  }

  factory SmartBasketRequestedItem.fromJsonMap(Map<String, dynamic> map) {
    final rawName = map['name'];
    final name = rawName is String ? rawName.trim() : '';

    double qty = 1.0;
    final rawQty = map['quantity'];
    if (rawQty is num) {
      qty = rawQty.toDouble();
    } else if (rawQty is String) {
      qty = double.tryParse(rawQty.trim()) ?? 1.0;
    }
    if (qty <= 0) qty = 1.0;
    if (qty > 100) qty = 100.0;

    final rawUnit = map['unit'];
    final unit = rawUnit is String ? normalizeUnit(rawUnit) : '';

    return SmartBasketRequestedItem(
      name: name,
      quantity: qty,
      unit: unit,
    );
  }
}

class SmartBasketRequest {
  final int? people;
  final double? budget;
  final List<SmartBasketRequestedItem> items;

  const SmartBasketRequest({
    this.people,
    this.budget,
    required this.items,
  });

  factory SmartBasketRequest.fromJsonMap(Map<String, dynamic> map) {
    int? people;
    final rawPeople = map['people'];
    if (rawPeople is num) {
      final p = rawPeople.toInt();
      if (p >= 1 && p <= 50) people = p;
    }

    double? budget;
    final rawBudget = map['budget'];
    if (rawBudget is num) {
      final b = rawBudget.toDouble();
      if (b >= 1 && b <= 1000000) budget = b;
    }

    final items = <SmartBasketRequestedItem>[];
    final rawItems = map['items'];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          final item = SmartBasketRequestedItem.fromJsonMap(raw);
          if (item.name.length >= 2 && item.name.length <= 40) {
            items.add(item);
            if (items.length == 15) break;
          }
        }
      }
    }

    return SmartBasketRequest(
      people: people,
      budget: budget,
      items: items,
    );
  }
}

class SmartBasketLine {
  final ProductModel product;
  final String farmerName;
  int quantity;
  final bool checkQuantity;
  final String? note;

  SmartBasketLine({
    required this.product,
    this.farmerName = '',
    required this.quantity,
    this.checkQuantity = false,
    this.note,
  });

  double get lineTotal => product.pricePerUnit * quantity;
}

class SmartBasketResult {
  final List<SmartBasketLine> lines;
  final List<String> notFoundItems;
  final double? budget;
  final List<String> budgetAdjustments;
  final bool isFallback;
  final String? message;

  const SmartBasketResult({
    required this.lines,
    required this.notFoundItems,
    this.budget,
    this.budgetAdjustments = const [],
    this.isFallback = false,
    this.message,
  });

  double get total => lines.fold(0.0, (acc, l) => acc + l.lineTotal);
  bool get isOverBudget => budget != null && total > budget!;
}

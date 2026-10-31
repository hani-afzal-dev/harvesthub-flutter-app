import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub/models/product_model.dart';
import 'package:harvesthub/models/smart_basket.dart';
import 'package:harvesthub/services/smart_basket_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now();
  final sampleProducts = [
    ProductModel(
      productId: 'p1',
      farmerId: 'f1',
      categoryId: 'c1',
      itemName: 'Sindhri Tamatar',
      pricePerUnit: 80,
      unit: 'kg',
      stockQty: 50,
      isAvailable: true,
      createdAt: now,
      updatedAt: now,
    ),
    ProductModel(
      productId: 'p2',
      farmerId: 'f2',
      categoryId: 'c1',
      itemName: 'Kela (Banana)',
      pricePerUnit: 120,
      unit: 'dozen',
      stockQty: 10,
      isAvailable: true,
      createdAt: now,
      updatedAt: now,
    ),
    ProductModel(
      productId: 'p3',
      farmerId: 'f1',
      categoryId: 'c1',
      itemName: 'Palak (Spinach)',
      pricePerUnit: 60,
      unit: 'kg',
      stockQty: 5,
      isAvailable: true,
      createdAt: now,
      updatedAt: now,
    ),
    ProductModel(
      productId: 'p4_unavailable',
      farmerId: 'f2',
      categoryId: 'c1',
      itemName: 'Organic Tamatar',
      pricePerUnit: 40,
      unit: 'kg',
      stockQty: 100,
      isAvailable: false, // out of catalog
      createdAt: now,
      updatedAt: now,
    ),
    ProductModel(
      productId: 'p5_zero_stock',
      farmerId: 'f1',
      categoryId: 'c1',
      itemName: 'Fresh Aloo (Potato)',
      pricePerUnit: 50,
      unit: 'kg',
      stockQty: 0, // zero stock
      isAvailable: true,
      createdAt: now,
      updatedAt: now,
    ),
    ProductModel(
      productId: 'p6_honey',
      farmerId: 'f1',
      categoryId: 'c1',
      itemName: 'Organic Honey',
      pricePerUnit: 1400,
      unit: 'kg',
      stockQty: 15,
      isAvailable: true,
      createdAt: now,
      updatedAt: now,
    ),
    ProductModel(
      productId: 'p7_tomato',
      farmerId: 'f2',
      categoryId: 'c1',
      itemName: 'Tomato',
      pricePerUnit: 90,
      unit: 'kg',
      stockQty: 20,
      isAvailable: true,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  group('SmartBasketRequest and Fallback Parser', () {
    final service = SmartBasketService();

    test('Fallback parser correctly parses "2 kg tamatar, 1 dozen kela"', () {
      final req = service.parseWithFallback('2 kg tamatar, 1 dozen kela');
      expect(req, isNotNull);
      expect(req!.items.length, 2);

      expect(req.items[0].name.toLowerCase(), contains('tamatar'));
      expect(req.items[0].quantity, 2);
      expect(req.items[0].unit, 'kg');

      expect(req.items[1].name.toLowerCase(), contains('kela'));
      expect(req.items[1].quantity, 1);
      expect(req.items[1].unit, 'dozen');
    });

    test('Fallback parser parses budget and items', () {
      final req = service.parseWithFallback('5 kg tamatar aur 2 dozen kela, Rs 3000 budget');
      expect(req, isNotNull);
      expect(req!.budget, 3000.0);
      expect(req.items.length, 2);
      expect(req.items[0].quantity, 5);
      expect(req.items[0].unit, 'kg');
    });

    test('Household-only requests without items return null for guidance', () {
      final req = service.parseWithFallback('5 log hafta bhar');
      expect(req, isNull);
    });

    test('Prompt injection in JSON is bounded by Dart validation', () {
      final maliciousJson = {
        'people': 999999,
        'budget': 0, // invalid budget
        'items': [
          {'name': 'Free Apples', 'quantity': 10000, 'unit': 'kg'},
          {'name': 'a' * 500, 'quantity': 1, 'unit': 'kg'}, // too long
        ],
      };

      final req = SmartBasketRequest.fromJsonMap(maliciousJson);
      expect(req.people, isNull); // bounded out
      expect(req.budget, isNull); // 0 is invalid
      expect(req.items.length, 1); // only valid length items accepted
      expect(req.items[0].quantity, 100.0); // quantity clamped to max 100
    });
  });

  group('SmartBasketService matching and budget maths', () {
    final service = SmartBasketService();

    test('Matches available products and ignores unavailable / zero-stock', () {
      const request = SmartBasketRequest(
        items: [
          SmartBasketRequestedItem(name: 'tamatar', quantity: 2, unit: 'kg'),
          SmartBasketRequestedItem(name: 'kela', quantity: 1, unit: 'dozen'),
          SmartBasketRequestedItem(name: 'aloo', quantity: 3, unit: 'kg'), // only zero stock exists
          SmartBasketRequestedItem(name: 'anar', quantity: 2, unit: 'kg'), // not in catalog
        ],
      );

      final result = service.buildBasket(
        request: request,
        availableProducts: sampleProducts,
      );

      // p4 (unavailable) and p5 (zero stock) must never be matched
      expect(result.lines.length, 2);
      expect(result.lines[0].product.productId, 'p1');
      expect(result.lines[0].quantity, 2);
      expect(result.lines[0].lineTotal, 160.0); // 80 * 2

      expect(result.lines[1].product.productId, 'p2');
      expect(result.lines[1].quantity, 1);
      expect(result.lines[1].lineTotal, 120.0); // 120 * 1

      expect(result.total, 280.0);
      expect(result.notFoundItems, contains('aloo'));
      expect(result.notFoundItems, contains('anar'));
    });

    test('Caps quantity to stock if requested quantity exceeds stock', () {
      const request = SmartBasketRequest(
        items: [
          SmartBasketRequestedItem(name: 'palak', quantity: 10, unit: 'kg'), // stock is 5
        ],
      );

      final result = service.buildBasket(
        request: request,
        availableProducts: sampleProducts,
      );

      expect(result.lines.length, 1);
      expect(result.lines[0].quantity, 5); // capped to stock
      expect(result.lines[0].lineTotal, 300.0); // 60 * 5
    });

    test('Marks checkQuantity if unit does not match product unit', () {
      const request = SmartBasketRequest(
        items: [
          SmartBasketRequestedItem(name: 'kela', quantity: 5, unit: 'piece'), // product sold by dozen
        ],
      );

      final result = service.buildBasket(
        request: request,
        availableProducts: sampleProducts,
      );

      expect(result.lines.length, 1);
      expect(result.lines[0].checkQuantity, isTrue);
      expect(result.lines[0].quantity, 1);
    });

    test('Budget math reduces quantity and drops items from end to fit budget', () {
      // Tamatar (80 * 5 = 400), Kela (120 * 2 = 240), Palak (60 * 3 = 180) -> Total = 820
      // Budget is 500
      const request = SmartBasketRequest(
        budget: 500.0,
        items: [
          SmartBasketRequestedItem(name: 'tamatar', quantity: 5, unit: 'kg'),
          SmartBasketRequestedItem(name: 'kela', quantity: 2, unit: 'dozen'),
          SmartBasketRequestedItem(name: 'palak', quantity: 3, unit: 'kg'),
        ],
      );

      final result = service.buildBasket(
        request: request,
        availableProducts: sampleProducts,
      );

      expect(result.total, lessThanOrEqualTo(500.0));
      expect(result.budgetAdjustments.isNotEmpty, isTrue);
    });

    test('isRequestInProgress reflects single concurrency lock', () {
      expect(service.isRequestInProgress, isFalse);
    });

    test('"honey" matches "Organic Honey"', () {
      const request = SmartBasketRequest(
        items: [
          SmartBasketRequestedItem(name: 'honey', quantity: 1, unit: 'kg'),
        ],
      );

      final result = service.buildBasket(
        request: request,
        availableProducts: sampleProducts,
      );

      expect(result.lines.length, 1);
      expect(result.lines[0].product.productId, 'p6_honey');
      expect(result.lines[0].product.itemName, 'Organic Honey');
      expect(result.lines[0].lineTotal, 1400.0);
      expect(result.notFoundItems, isEmpty);
    });

    test('a product with no itemNameLower still matches', () {
      final productNoLower = ProductModel(
        productId: 'p_nolower',
        farmerId: 'f1',
        categoryId: 'c1',
        itemName: 'Organic Honey',
        pricePerUnit: 1400,
        unit: 'kg',
        stockQty: 10,
        isAvailable: true,
        createdAt: now,
        updatedAt: now,
      );

      const request = SmartBasketRequest(
        items: [
          SmartBasketRequestedItem(name: 'honey', quantity: 1, unit: 'kg'),
        ],
      );

      final result = service.buildBasket(
        request: request,
        availableProducts: [productNoLower],
      );

      expect(result.lines.length, 1);
      expect(result.lines[0].product.itemName, 'Organic Honey');
      expect(result.lines[0].quantity, 1);
    });

    test('"tamatar" matches "Tomato" via synonym mapping', () {
      const request = SmartBasketRequest(
        items: [
          SmartBasketRequestedItem(name: 'tamatar', quantity: 1, unit: 'kg'),
        ],
      );

      // Explicitly test matching against "Tomato"
      final tomatoProduct = sampleProducts.firstWhere((p) => p.productId == 'p7_tomato');
      final result = service.buildBasket(
        request: request,
        availableProducts: [tomatoProduct],
      );

      expect(result.lines.length, 1);
      expect(result.lines[0].product.itemName, 'Tomato');
      expect(result.notFoundItems, isEmpty);
    });
  });
}

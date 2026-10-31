import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub/core/ai_fallback_kb.dart';
import 'package:harvesthub/core/order_number.dart';
import 'package:harvesthub/core/product_search.dart';
import 'package:harvesthub/models/product_model.dart';
import 'package:harvesthub/models/promo_code_model.dart';

ProductModel product(String name) => ProductModel(
      productId: name.toLowerCase().replaceAll(' ', '_'),
      farmerId: 'farm',
      categoryId: 'fruits',
      itemName: name,
      pricePerUnit: 100,
      unit: 'kg',
      stockQty: 10,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  group('product search', () {
    final pool = [
      product('Sindhri Mango'),
      product('Mango Pulp'),
      product('Basmati Rice'),
      product('Masoor Dal'),
      product('Chana Dal'),
      product('Buffalo Milk'),
    ];

    List<String> names(String query) =>
        [for (final p in matchProductsByName(pool, query, 20)) p.itemName];

    test('finds a word in the middle of a name', () {
      expect(names('mango'), ['Mango Pulp', 'Sindhri Mango']);
      expect(names('rice'), ['Basmati Rice']);
      expect(names('milk'), ['Buffalo Milk']);
    });

    test('matches every word and ignores case and extra spaces', () {
      expect(names('  DAL  chana '), ['Chana Dal']);
      expect(names('dal'), ['Masoor Dal', 'Chana Dal']);
    });

    test('returns nothing for blank or unknown text', () {
      expect(names('   '), isEmpty);
      expect(names('pineapple'), isEmpty);
    });

    test('respects the limit', () {
      expect(matchProductsByName(pool, 'a', 2).length, 2);
    });
  });

  group('promo discount', () {
    PromoCodeModel promo(String type, double value, double min, double max) =>
        PromoCodeModel(
          code: 'TEST10',
          type: type,
          value: value,
          minOrder: min,
          maxDiscount: max,
          active: true,
          expiresAt: DateTime(2100),
          createdAt: DateTime(2026),
        );

    test('percent codes are capped at the maximum', () {
      expect(promo('percent', 20, 200, 50).discountFor(1000), 50);
      expect(promo('percent', 20, 200, 50).discountFor(200), 40);
    });

    test('nothing below the minimum order', () {
      expect(promo('percent', 20, 200, 50).discountFor(150), 0);
      expect(promo('flat', 100, 1000, 100).discountFor(999), 0);
    });

    test('flat discount never exceeds the subtotal', () {
      expect(promo('flat', 100, 0, 100).discountFor(60), 60);
    });
  });

  group('order number', () {
    test('is six digits and stable for the same id', () {
      final number = orderNumber('UhrhWLRu');
      expect(number, matches(RegExp(r'^#\d{6}$')));
      expect(orderNumber('UhrhWLRu'), number);
    });

    test('differs for different ids', () {
      expect(orderNumber('order_o6'), isNot(orderNumber('order_o7')));
    });
  });

  group('offline assistant', () {
    test('answers the suggested questions', () {
      for (final question in [
        'Which fruits are rich in Vitamin C?',
        'How should tomatoes be stored?',
        'Which vegetables are in season now?',
        'Health benefits of spinach',
        'Vegetables for a healthy salad',
      ]) {
        expect(matchAiFallbackAnswer(question), isNot(aiFallbackDefaultAnswer),
            reason: question);
      }
    });

    test('falls back politely for unknown questions', () {
      expect(matchAiFallbackAnswer('What is the capital of France?'),
          aiFallbackDefaultAnswer);
    });
  });
}

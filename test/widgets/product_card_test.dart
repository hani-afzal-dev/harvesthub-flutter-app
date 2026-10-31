import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub/models/product_model.dart';
import 'package:harvesthub/widgets/product_card.dart';

ProductModel sample({
  String name = 'Sindhri Mango',
  double price = 320,
  int stock = 60,
  String unit = 'kg',
}) =>
    ProductModel(
      productId: 'p1',
      farmerId: 'farm',
      categoryId: 'fruits',
      itemName: name,
      pricePerUnit: price,
      unit: unit,
      stockQty: stock,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Widget cardAt(double width, TextScaler scaler, ProductModel product,
    {VoidCallback? onAdd, bool compact = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: const Size(400, 900), textScaler: scaler),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: ProductCard.heightFor(width, scaler, compact: compact),
            child: ProductCard(
              product: product,
              farmerName: 'Malik Dairy and Pulses Cooperative',
              categoryName: 'Herbs and Spices',
              onTap: () {},
              onAdd: onAdd ?? () {},
              compact: compact,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  const cardWidths = {'small phone': 138.0, 'phone': 158.0, 'tablet': 248.0};
  const textScales = [1.0, 1.3, 2.0];
  final cases = {
    'normal': sample(),
    'low stock': sample(stock: 3),
    'out of stock': sample(stock: 0),
    'long name and high price': sample(
      name: 'Extra Large Organic Sindhri Mango From The Northern Hills',
      price: 1250000,
      unit: 'dozen',
    ),
  };

  for (final width in cardWidths.entries) {
    for (final scale in textScales) {
      for (final item in cases.entries) {
        testWidgets('no overflow: ${width.key}, text x$scale, ${item.key}',
            (tester) async {
          await tester.pumpWidget(
              cardAt(width.value, TextScaler.linear(scale), item.value));
          await tester.pump();
          expect(tester.takeException(), isNull);
        });
        testWidgets(
            'no overflow compact: ${width.key}, text x$scale, ${item.key}',
            (tester) async {
          await tester.pumpWidget(cardAt(
              width.value, TextScaler.linear(scale), item.value,
              compact: true));
          await tester.pump();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('add button does nothing when out of stock', (tester) async {
    var added = 0;
    await tester.pumpWidget(cardAt(180, TextScaler.noScaling, sample(stock: 0),
        onAdd: () => added++));
    await tester.tap(find.byIcon(Icons.add_rounded));
    expect(added, 0);
    expect(find.text('Out of stock'), findsOneWidget);
  });

  testWidgets('add button works when in stock', (tester) async {
    var added = 0;
    await tester.pumpWidget(
        cardAt(180, TextScaler.noScaling, sample(), onAdd: () => added++));
    await tester.tap(find.byIcon(Icons.add_rounded));
    expect(added, 1);
  });
}

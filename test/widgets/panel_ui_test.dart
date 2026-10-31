import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub/widgets/panel_ui.dart';

Future<void> pumpAt(
    WidgetTester tester, double width, double scale, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
          size: Size(width, 800), textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('stat strip fits at ${width}px, text x$scale',
          (tester) async {
        await pumpAt(
          tester,
          width,
          scale,
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: PanelStatStrip(stats: [
              ('1,234', 'Need restock'),
              ('Rs. 1,250,000', 'Open value'),
              ('99', 'Cancelled'),
            ]),
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('header with long title fits at ${width}px, text x$scale',
          (tester) async {
        await pumpAt(
          tester,
          width,
          scale,
          PanelHeader(
            title: 'Pickup slots for Malik Dairy and Pulses',
            subtitle:
                '12 new orders need your reply before the market opens today',
            trailing: IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('status pills wrap at ${width}px, text x$scale',
          (tester) async {
        await pumpAt(
          tester,
          width,
          scale,
          const Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusPill(
                  label: 'Awaiting verification',
                  icon: Icons.pending_outlined,
                  color: PanelColors.amber,
                  background: PanelColors.amberBg),
              StatusPill(
                  label: 'Ready for pickup',
                  icon: Icons.shopping_bag_outlined,
                  color: PanelColors.brand,
                  background: PanelColors.tint),
            ],
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('filter chips report the tapped index', (tester) async {
    var selected = 0;
    await pumpAt(
      tester,
      360,
      1.0,
      StatefulBuilder(
        builder: (context, setState) => FilterChipBar(
          labels: const ['All', 'Low stock', 'Hidden'],
          counts: const [18, 2, 1],
          selected: selected,
          onSelected: (i) => setState(() => selected = i),
        ),
      ),
    );
    await tester.tap(find.text('Low stock'));
    await tester.pump();
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state button works on a small screen with big text',
      (tester) async {
    var tapped = false;
    await pumpAt(
      tester,
      320,
      2.0,
      SizedBox(
        height: 500,
        child: PanelEmptyState(
          icon: Icons.eco_outlined,
          title: 'No products yet',
          message: 'List your first item so customers can find and order it.',
          actionLabel: 'Add product',
          onAction: () => tapped = true,
        ),
      ),
    );
    await tester.ensureVisible(find.text('Add product'));
    await tester.tap(find.text('Add product'));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  test('search matching helper', () {
    expect(matchesSearch('', ['anything']), isTrue);
    expect(matchesSearch('raza', ['Raza Orchards', 'ali@x.pk']), isTrue);
    expect(matchesSearch('zzz', ['Raza Orchards']), isFalse);
  });
}

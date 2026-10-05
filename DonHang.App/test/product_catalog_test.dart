import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:donhang_app/l10n/app_localizations.dart';
import 'package:donhang_app/models.dart';
import 'package:donhang_app/widgets/product_catalog.dart';
import 'package:donhang_app/widgets/product_tile.dart';

// lesson: frontend.l1.responsive-basics
// The same catalog given two widths: a list when narrow, a grid when wide.
void main() {
  final products = [
    Product(id: 1, name: 'Bàn phím cơ', priceVnd: 1250000),
    Product(id: 2, name: 'Chuột không dây', priceVnd: 450000),
  ];

  // From stage-2 the tiles read their text from AppLocalizations, so the
  // test app provides it, in Vietnamese.
  Widget catalogWithWidth(double width) => MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, height: 400, child: ProductCatalog(products: products)),
          ),
        ),
      );

  testWidgets('a narrow width shows a single-column list', (tester) async {
    await tester.pumpWidget(catalogWithWidth(360));

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('a wide width shows a grid of the same tiles', (tester) async {
    await tester.pumpWidget(catalogWithWidth(900));

    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(ProductTile), findsNWidgets(2));
  });

  // lesson: frontend.l1.accessibility-basics
  testWidgets('each tile is at least 48 pixels tall and has a spoken label', (tester) async {
    await tester.pumpWidget(catalogWithWidth(360));

    expect(tester.getSize(find.byType(ProductTile).first).height, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel('Bàn phím cơ, 1.250.000 đồng'), findsOneWidget);
  });

  // lesson: frontend.l3.lazy-lists
  // 10 000 products in memory, but ListView.builder builds tiles only for
  // the 400 pixels on screen and a little beyond: the first products have a
  // tile, the last one has none, and far fewer than 10 000 tiles exist.
  testWidgets('a long list builds only the tiles near the screen', (tester) async {
    final many = [for (var id = 1; id <= 10000; id++) Product(id: id, name: 'Product $id', priceVnd: 1000)];
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(child: SizedBox(width: 360, height: 400, child: ProductCatalog(products: many))),
      ),
    ));

    expect(find.text('Product 1'), findsOneWidget);
    expect(find.text('Product 10000'), findsNothing);
    expect(tester.widgetList(find.byType(ProductTile)).length, lessThan(30));
  });
}

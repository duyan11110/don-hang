import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  Widget catalogWithWidth(double width) => MaterialApp(
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
    expect(find.bySemanticsLabel('Bàn phím cơ, 1250000 đồng'), findsOneWidget);
  });
}

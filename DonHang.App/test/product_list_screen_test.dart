import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:donhang_app/l10n/app_localizations.dart';
import 'package:donhang_app/models.dart';
import 'package:donhang_app/providers.dart';
import 'package:donhang_app/screens/product_list_screen.dart';

// lesson: frontend.l2.overriding-providers-in-tests
// The screen as the app builds it, but productsProvider holds a fixed value
// instead of calling the API: no server, no HTTP request.
Widget screenWith(AsyncValue<List<Product>> products) => ProviderScope(
      overrides: [productsProvider.overrideWithValue(products)],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProductListScreen(),
      ),
    );

void main() {
  // lesson: frontend.l2.overriding-providers-in-tests
  // One test per state; each override lives only in its own ProviderScope.
  testWidgets('shows the products the provider holds', (tester) async {
    await tester.pumpWidget(screenWith(AsyncValue.data([
      Product(id: 1, name: 'Bàn phím cơ', priceVnd: 1250000),
      Product(id: 2, name: 'Chuột không dây', priceVnd: 450000),
    ])));

    expect(find.text('Bàn phím cơ'), findsOneWidget);
    expect(find.text('Chuột không dây'), findsOneWidget);
  });

  testWidgets('says so when there are no products', (tester) async {
    await tester.pumpWidget(screenWith(const AsyncValue.data([])));

    expect(find.text('No products yet.'), findsOneWidget);
  });

  testWidgets('shows the error text when loading failed', (tester) async {
    await tester.pumpWidget(screenWith(AsyncValue.error(Exception('offline'), StackTrace.empty)));

    expect(find.text('Could not load products.'), findsOneWidget);
  });
}

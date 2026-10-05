import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:donhang_app/api_client.dart';
import 'package:donhang_app/design/brand.dart';
import 'package:donhang_app/design/theme.dart';
import 'package:donhang_app/l10n/app_localizations.dart';
import 'package:donhang_app/models.dart';
import 'package:donhang_app/offline/local_store.dart';
import 'package:donhang_app/providers.dart';
import 'package:donhang_app/screens/product_list_screen.dart';

// An API that answers with a fixed list, or that cannot be reached.
class FakeProductsApi extends ApiClient {
  final List<Product>? products;

  FakeProductsApi(this.products) : super(readToken: () => null);

  @override
  Future<List<Product>> fetchProducts() async {
    final answer = products;
    if (answer == null) throw Exception('no answer from the API');
    return answer;
  }
}

Widget screenWith(LocalStore store, ApiClient api) => ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        apiClientProvider.overrideWithValue(api),
      ],
      child: MaterialApp(
        theme: buildTheme(donHangBrand, Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ProductListScreen(),
      ),
    );

void main() {
  // lesson: frontend.l3.offline-first
  // A list saved on an earlier visit, then an API that does not answer: the
  // screen keeps the saved list and says it may be out of date, instead of
  // a spinner or an error.
  testWidgets('shows the saved list when the API does not answer', (tester) async {
    final store = MemoryLocalStore();
    store.write(savedProductsKey, jsonEncode([Product(id: 1, name: 'Bàn phím cơ', priceVnd: 1250000).toJson()]));

    await tester.pumpWidget(screenWith(store, FakeProductsApi(null)));
    await tester.pump();

    expect(find.text('Bàn phím cơ'), findsOneWidget);
    expect(find.textContaining('Showing the saved list'), findsOneWidget);
  });

  testWidgets('saves each fresh list for the next visit', (tester) async {
    final store = MemoryLocalStore();
    final fresh = [Product(id: 2, name: 'Chuột không dây', priceVnd: 450000)];

    await tester.pumpWidget(screenWith(store, FakeProductsApi(fresh)));
    await tester.pump();

    expect(find.text('Chuột không dây'), findsOneWidget);
    expect(find.textContaining('Showing the saved list'), findsNothing);
    expect(readSavedProducts(store)!.single.name, 'Chuột không dây');
  });

  testWidgets('with nothing saved and no answer, says it could not load', (tester) async {
    await tester.pumpWidget(screenWith(MemoryLocalStore(), FakeProductsApi(null)));
    await tester.pump();

    expect(find.text('Could not load products.'), findsOneWidget);
  });
}

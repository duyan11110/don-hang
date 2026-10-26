import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:donhang_app/design/brand.dart';
import 'package:donhang_app/design/theme.dart';
import 'package:donhang_app/features/catalog/catalog_providers.dart';
import 'package:donhang_app/features/catalog/product.dart';
import 'package:donhang_app/features/ordering/create_order_screen.dart';
import 'package:donhang_app/features/ordering/order.dart';
import 'package:donhang_app/features/ordering/orders_api.dart';
import 'package:donhang_app/l10n/app_localizations.dart';
import 'package:donhang_app/shared/api_client.dart';

// lesson: frontend.l2.server-errors-in-forms
// A fake OrdersApi whose createOrder always fails the way DonHang.Api does
// when an item breaks a rule: 400 with a Problem Details body.
class RejectingOrdersApi extends OrdersApi {
  RejectingOrdersApi() : super(ApiClient());

  @override
  Future<OrderResult> createOrder(List<OrderItemRequest> items, {required String idempotencyKey}) async {
    throw ApiProblem(
      status: 400,
      type: 'about:blank',
      title: 'Invalid request',
      detail: 'every item needs a quantity of at least 1',
    );
  }
}

void main() {
  // lesson: frontend.l2.server-errors-in-forms
  testWidgets('shows the API detail and keeps what was typed', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ordersApiProvider.overrideWithValue(RejectingOrdersApi()),
        productsProvider.overrideWithValue(AsyncValue.data(LoadedProducts([Product(id: 1, name: 'Bàn phím cơ', priceVnd: 1250000)]))),
      ],
      // From stage-3 the server's error is a StatusBanner, whose colors
      // come from the app's theme, so the test app uses that theme too.
      child: MaterialApp(
        theme: buildTheme(donHangBrand, Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CreateOrderScreen(),
      ),
    ));
    await tester.pump();

    await tester.tap(find.byType(DropdownButtonFormField<Product>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bàn phím cơ').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '2');
    await tester.tap(find.text('Place order'));
    await tester.pumpAndSettle();

    expect(find.text('every item needs a quantity of at least 1'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '2'), findsOneWidget);
  });

  // lesson: frontend.l2.form-validation
  testWidgets('does not send an order the validators reject', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ordersApiProvider.overrideWithValue(RejectingOrdersApi()),
        productsProvider.overrideWithValue(AsyncValue.data(LoadedProducts([Product(id: 1, name: 'Bàn phím cơ', priceVnd: 1250000)]))),
      ],
      // From stage-3 the server's error is a StatusBanner, whose colors
      // come from the app's theme, so the test app uses that theme too.
      child: MaterialApp(
        theme: buildTheme(donHangBrand, Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CreateOrderScreen(),
      ),
    ));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.text('Place order'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a product.'), findsOneWidget);
    expect(find.text('Enter a whole number, 1 or more.'), findsOneWidget);
    expect(find.text('every item needs a quantity of at least 1'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:donhang_app/auth/auth_controller.dart';
import 'package:donhang_app/l10n/app_localizations.dart';
import 'package:donhang_app/models.dart';
import 'package:donhang_app/providers.dart';
import 'package:donhang_app/screens/product_list_screen.dart';
import 'package:donhang_app/widgets/product_catalog.dart';

// Starts signed in, without Keycloak: build() returns a token at once.
class SignedInAuth extends AuthController {
  @override
  String? build() => 'header.payload.signature';
}

// lesson: frontend.l3.rebuild-scope
// Signing out changes authProvider. Only SignInOutButton watches it, so the
// screen's build does not run again and ProductCatalog is the very same
// widget instance as before: Flutter skips its whole subtree.
void main() {
  testWidgets('signing out rebuilds the button, not the catalog', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(SignedInAuth.new),
        productsProvider.overrideWithValue(AsyncValue.data(LoadedProducts([
          Product(id: 1, name: 'Bàn phím cơ', priceVnd: 1250000),
        ]))),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProductListScreen(),
      ),
    ));
    final catalogBefore = tester.widget<ProductCatalog>(find.byType(ProductCatalog));

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pump();

    expect(find.byTooltip('Sign in'), findsOneWidget);
    expect(identical(tester.widget<ProductCatalog>(find.byType(ProductCatalog)), catalogBefore), isTrue);
  });
}

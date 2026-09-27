import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:donhang_app/main.dart';
import 'package:donhang_app/models.dart';
import 'package:donhang_app/providers.dart';

void main() {
  // The whole app, router included, opens on the product list at `/`. The
  // product list never arrives here, so the screen stays in its loading state.
  testWidgets('opens on the product list screen, loading', (WidgetTester tester) async {
    final neverLoads = Completer<List<Product>>();
    await tester.pumpWidget(ProviderScope(
      overrides: [productsProvider.overrideWith((ref) => neverLoads.future)],
      child: const DonHangApp(),
    ));
    await tester.pump();

    expect(find.text('Đơn Hàng'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

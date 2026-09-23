import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:donhang_app/main.dart';

void main() {
  testWidgets('shows the product list screen and starts loading', (WidgetTester tester) async {
    await tester.pumpWidget(const DonHangApp());

    expect(find.text('Đơn Hàng'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'api_client.dart';
import 'screens/product_list_screen.dart';

void main() {
  runApp(const DonHangApp());
}

// lesson: frontend.l1.composing-widgets
// One StatelessWidget composing the app shell; every screen below it is its
// own small widget (design.l1.solid-srp applied to widgets, not classes).
class DonHangApp extends StatelessWidget {
  const DonHangApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();
    return MaterialApp(
      title: 'Đơn Hàng',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: ProductListScreen(apiClient: apiClient),
    );
  }
}

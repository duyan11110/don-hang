import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:donhang_app/features/catalog/product.dart';
import 'package:donhang_app/features/ordering/order.dart';

// lesson: frontend.l4.app-api-contract
// The app's side of the contract with DonHang.Api: ../contracts/app/ holds
// one sample answer per shape, with only the fields DonHang.App reads, and
// the app's own fromJson must read each sample. DonHang.Tests'
// AppContractTests checks the other side: the API's answers still carry
// every field of these samples, with the same JSON type.
Map<String, dynamic> sample(String name) =>
    jsonDecode(File('../contracts/app/$name').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('Product.fromJson reads the product sample', () {
    final json = sample('product.json');
    final product = Product.fromJson(json);

    expect(product.id, json['id']);
    expect(product.name, json['name']);
    expect(product.priceVnd, json['priceVnd']);
  });

  test('OrderResult.fromJson reads the order sample', () {
    final json = sample('order.json');
    final order = OrderResult.fromJson(json);
    final item = (json['items'] as List<dynamic>).single as Map<String, dynamic>;

    expect(order.id, json['id']);
    expect(order.status, json['status']);
    expect(order.items.single.productId, item['productId']);
    expect(order.items.single.quantity, item['quantity']);
    expect(order.items.single.unitPriceVnd, item['unitPriceVnd']);
  });
}

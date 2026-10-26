import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api_client.dart';
import 'product.dart';

// lesson: frontend.l4.backend-for-frontend
// The Catalog feature's calls to DonHang.Api: one request per screen, and
// the answer is already the shape the screen shows. Products are public,
// so these requests carry no token.
class CatalogApi {
  final ApiClient _client;

  CatalogApi(this._client);

  Future<List<Product>> fetchProducts() async {
    final response = await _client.get('/products');
    if (response.statusCode != 200) {
      throw Exception('failed to load products (${response.statusCode})');
    }
    final items = jsonDecode(response.body) as List<dynamic>;
    return items.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Product> fetchProduct(int id) async {
    final response = await _client.get('/products/$id');
    if (response.statusCode != 200) {
      throw Exception('failed to load product $id (${response.statusCode})');
    }
    return Product.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

// lesson: frontend.l2.riverpod-providers
// Each provider is declared once, at the top level, and says how to make
// one value. The value itself is kept by the ProviderScope in main.dart,
// made the first time something reads it and shared by every later read.
// From stage-4 each feature declares its own; tests replace this one with
// a fake CatalogApi.
final catalogApiProvider = Provider<CatalogApi>((ref) => CatalogApi(ApiClient()));

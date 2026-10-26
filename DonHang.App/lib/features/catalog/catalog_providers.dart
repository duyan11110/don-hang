import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/local_store.dart';
import 'catalog_api.dart';
import 'product.dart';

// Riverpod 3.0 retries a FutureProvider whose Future fails with an Exception:
// up to 10 more times, 200 ms apart at first, doubling up to 6.4 s. While it
// retries, the AsyncValue is loading (with the error attached), so a screen
// using AsyncValue.when shows its spinner, and its error builder only after
// the last attempt fails, about 38 s later. DonHang.App keeps that default,
// except for productsProvider from stage-3 (below); the refresh button
// (ref.invalidate) still starts a new load at any time.
// Widget tests that want the error state set it directly with
// overrideWithValue(AsyncValue.error(...)), which involves no retry.

// The product list a screen shows, and whether it is the saved copy that
// the API could not refresh just now.
class LoadedProducts {
  final List<Product> items;
  final bool outOfDate;

  const LoadedProducts(this.items, {this.outOfDate = false});
}

const String savedProductsKey = 'donhang.products';

// lesson: frontend.l3.offline-first
// Offline-first: the saved copy is shown at once, then the API is asked for
// a fresh list, which replaces the copy on screen and on the device. When
// that fails the saved copy stays, marked out of date. Riverpod's retry is
// off here: with a copy on screen there is nothing to wait for.
final productsProvider = StreamProvider<LoadedProducts>((ref) async* {
  final store = ref.watch(localStoreProvider);
  final api = ref.watch(catalogApiProvider);
  final saved = readSavedProducts(store);
  if (saved != null) yield LoadedProducts(saved);
  try {
    final fresh = await api.fetchProducts();
    store.write(savedProductsKey, jsonEncode([for (final product in fresh) product.toJson()]));
    yield LoadedProducts(fresh);
  } on Exception {
    if (saved == null) rethrow;
    yield LoadedProducts(saved, outOfDate: true);
  }
}, retry: (retryCount, error) => null);

List<Product>? readSavedProducts(LocalStore store) {
  final saved = store.read(savedProductsKey);
  if (saved == null) return null;
  return [for (final item in jsonDecode(saved) as List<dynamic>) Product.fromJson(item as Map<String, dynamic>)];
}

// lesson: frontend.l2.deep-links
// A family: one value per id. productProvider(3) loads product 3 on its own,
// so a screen opened straight from /products/3 needs nothing from the list.
final productProvider = FutureProvider.family<Product, int>((ref, id) {
  return ref.watch(catalogApiProvider).fetchProduct(id);
});

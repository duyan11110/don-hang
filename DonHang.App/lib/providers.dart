import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'auth/auth_controller.dart';
import 'models.dart';

// Riverpod 3.0 retries a FutureProvider whose Future fails with an Exception:
// up to 10 more times, 200 ms apart at first, doubling up to 6.4 s. While it
// retries, the AsyncValue is loading (with the error attached), so a screen
// using AsyncValue.when shows its spinner, and its error builder only after
// the last attempt fails, about 38 s later. DonHang.App keeps that default;
// the refresh button (ref.invalidate) still starts a new load at any time.
// Widget tests that want the error state set it directly with
// overrideWithValue(AsyncValue.error(...)), which involves no retry.

// lesson: frontend.l2.riverpod-providers
// Each provider is declared once, at the top level, and says how to make
// one value. The value itself is kept by the ProviderScope in main.dart,
// made the first time something reads it and shared by every later read.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(readToken: () => ref.read(authProvider));
});

// lesson: frontend.l2.futureprovider-and-asyncvalue
// lesson: frontend.l2.overriding-providers-in-tests
// Loads the product list once and keeps it; ref.invalidate(productsProvider)
// throws it away so the next read loads it again.
final productsProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(apiClientProvider).fetchProducts();
});

// lesson: frontend.l2.deep-links
// A family: one value per id. productProvider(3) loads product 3 on its own,
// so a screen opened straight from /products/3 needs nothing from the list.
final productProvider = FutureProvider.family<Product, int>((ref, id) {
  return ref.watch(apiClientProvider).fetchProduct(id);
});

// Watching authProvider too: signing in as someone else loads the order
// again with the new token instead of showing the previous customer's copy.
final orderProvider = FutureProvider.family<OrderResult, int>((ref, id) {
  ref.watch(authProvider);
  return ref.watch(apiClientProvider).fetchOrder(id);
});

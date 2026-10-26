import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../shared/api_client.dart';
import '../auth/auth.dart';
import 'order.dart';

// lesson: frontend.l4.backend-for-frontend
// The Ordering feature's calls to DonHang.Api, each a single request whose
// answer the screen shows as it is. Orders belong to a customer, so these
// requests carry the signed-in customer's token.
class OrdersApi {
  final ApiClient _client;

  OrdersApi(this._client);

  Future<OrderResult> fetchOrder(int id) async {
    final response = await _client.get('/orders/$id', signedIn: true);
    if (response.statusCode != 200) {
      throw Exception('failed to load order $id (${response.statusCode})');
    }
    return OrderResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // lesson: frontend.l1.creating-an-order
  // lesson: frontend.l2.server-errors-in-forms
  // Anything but 201 comes back as an ApiProblem built from the body, so a
  // screen can show the server's own explanation, not just a status code.
  // lesson: frontend.l3.offline-order-queue
  // From stage-3 every order carries an Idempotency-Key, and "no answer from
  // the API" is its own exception: no response at all, or a 502, 503 or 504,
  // which only says the proxy in front of the API could not reach it.
  Future<OrderResult> createOrder(List<OrderItemRequest> items, {required String idempotencyKey}) async {
    final http.Response response;
    try {
      response = await _client.post(
        '/orders',
        {'items': items.map((item) => item.toJson()).toList()},
        headers: {'Idempotency-Key': idempotencyKey},
      );
    } on http.ClientException {
      throw ApiUnreachable();
    }
    if (const [502, 503, 504].contains(response.statusCode)) throw ApiUnreachable();
    if (response.statusCode != 201) throw ApiProblem.fromResponse(response);
    return OrderResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

// lesson: frontend.l2.notifier-for-app-state
// The token comes from authProvider at the moment of each request, so a
// customer who signs in or out is seen by the next call. Tests replace
// this provider with a fake OrdersApi.
final ordersApiProvider = Provider<OrdersApi>((ref) {
  return OrdersApi(ApiClient(readToken: () => ref.read(authProvider)));
});

// Watching authProvider too: signing in as someone else loads the order
// again with the new token instead of showing the previous customer's copy.
final orderProvider = FutureProvider.family<OrderResult, int>((ref, id) {
  ref.watch(authProvider);
  return ref.watch(ordersApiProvider).fetchOrder(id);
});

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:donhang_app/api_client.dart';
import 'package:donhang_app/models.dart';

final items = [OrderItemRequest(productId: 1, quantity: 2, unitPriceVnd: 1000)];

ApiClient clientAnswering(int status, {Map<String, String> headers = const {}}) => ApiClient(
      readToken: () => 'a.token',
      httpClient: MockClient((request) async => http.Response('{}', status, headers: headers)),
    );

void main() {
  // lesson: frontend.l3.offline-order-queue
  // Only "no answer" is ApiUnreachable; a 400 or 409 is the API's answer.
  test('every order carries its Idempotency-Key', () async {
    String? keySent;
    final client = ApiClient(
      readToken: () => 'a.token',
      httpClient: MockClient((request) async {
        keySent = request.headers['Idempotency-Key'];
        return http.Response(jsonEncode({'id': 7, 'status': 'pending', 'items': []}), 201);
      }),
    );

    await client.createOrder(items, idempotencyKey: 'key-1');

    expect(keySent, 'key-1');
  });

  for (final status in [502, 503, 504]) {
    test('a $status from the proxy means no answer', () async {
      expect(clientAnswering(status).createOrder(items, idempotencyKey: 'k'), throwsA(isA<ApiUnreachable>()));
    });
  }

  test('no response at all means no answer', () async {
    final client = ApiClient(
      readToken: () => null,
      httpClient: MockClient((request) async => throw http.ClientException('connection refused')),
    );
    expect(client.createOrder(items, idempotencyKey: 'k'), throwsA(isA<ApiUnreachable>()));
  });

  test('a 400 is an answer: an ApiProblem', () async {
    expect(clientAnswering(400).createOrder(items, idempotencyKey: 'k'), throwsA(isA<ApiProblem>()));
  });

  test('a 429 carries how long Retry-After asks to wait', () async {
    try {
      await clientAnswering(429, headers: {'retry-after': '30'}).createOrder(items, idempotencyKey: 'k');
      fail('expected an ApiProblem');
    } on ApiProblem catch (problem) {
      expect(problem.retryAfter, const Duration(seconds: 30));
    }
  });
}

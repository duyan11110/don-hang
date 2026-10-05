import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

// lesson: frontend.l1.fetching-with-http-package
// One place that knows the api's base URL and how to attach a token; every
// screen calls through here instead of using package:http directly.
class ApiClient {
  // Caddy proxies /api/v1/* to DonHang.Api (see ../../Caddyfile); this app is
  // served by a different container (app-web:8081) so it always goes through
  // Caddy on :8080, never straight to the api container.
  static const String baseUrl = 'http://localhost:8080/api/v1';

  // lesson: frontend.l2.notifier-for-app-state
  // No token field of its own any more: every request asks for the current
  // token, whose only copy is in authProvider (see apiClientProvider).
  final String? Function() readToken;

  // From stage-3 a test can hand in a fake http.Client (package:http/testing.dart).
  final http.Client _http;

  ApiClient({required this.readToken, http.Client? httpClient}) : _http = httpClient ?? http.Client();

  Map<String, String> get _headers {
    final token = readToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Product>> fetchProducts() async {
    final response = await _http.get(Uri.parse('$baseUrl/products'));
    if (response.statusCode != 200) {
      throw Exception('failed to load products (${response.statusCode})');
    }
    final items = jsonDecode(response.body) as List<dynamic>;
    return items.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Product> fetchProduct(int id) async {
    final response = await _http.get(Uri.parse('$baseUrl/products/$id'));
    if (response.statusCode != 200) {
      throw Exception('failed to load product $id (${response.statusCode})');
    }
    return Product.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<OrderResult> fetchOrder(int id) async {
    final response = await _http.get(Uri.parse('$baseUrl/orders/$id'), headers: _headers);
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
      response = await _http.post(
        Uri.parse('$baseUrl/orders'),
        headers: {..._headers, 'Idempotency-Key': idempotencyKey},
        body: jsonEncode({'items': items.map((item) => item.toJson()).toList()}),
      );
    } on http.ClientException {
      throw ApiUnreachable();
    }
    if (const [502, 503, 504].contains(response.statusCode)) throw ApiUnreachable();
    if (response.statusCode != 201) throw ApiProblem.fromResponse(response);
    return OrderResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

// lesson: frontend.l3.offline-order-queue
// The request may or may not have reached the API; nobody answered. Only
// this puts an order in the offline queue: a 400 or 409 is an answer.
class ApiUnreachable implements Exception {
  @override
  String toString() => 'ApiUnreachable';
}

// lesson: frontend.l2.server-errors-in-forms
// An RFC 9457 Problem Details body (application/problem+json) as a Dart
// object. A response with no such body, such as a bare 401 or 403, still
// becomes one, with the status code as its detail.
class ApiProblem implements Exception {
  final int status;
  final String type;
  final String title;
  final String detail;
  // From stage-3: how long a 429 asks the client to wait (Retry-After, in
  // seconds), or null when the response does not say.
  final Duration? retryAfter;

  ApiProblem({required this.status, required this.type, required this.title, required this.detail, this.retryAfter});

  factory ApiProblem.fromResponse(http.Response response) {
    final body = _jsonObjectOrEmpty(response.body);
    return ApiProblem(
      status: response.statusCode,
      // No `type` means "about:blank": nothing more specific than the status.
      type: body['type'] as String? ?? 'about:blank',
      title: body['title'] as String? ?? 'HTTP ${response.statusCode}',
      detail: body['detail'] as String? ?? body['title'] as String? ?? 'HTTP ${response.statusCode}',
      retryAfter: _seconds(response.headers['retry-after']),
    );
  }

  static Duration? _seconds(String? header) {
    final seconds = int.tryParse(header ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }

  static Map<String, dynamic> _jsonObjectOrEmpty(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } on FormatException {
      return {};
    }
  }

  @override
  String toString() => 'ApiProblem($status, $type): $detail';
}

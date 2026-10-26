import 'dart:convert';
import 'package:http/http.dart' as http;

// lesson: frontend.l1.fetching-with-http-package
// One place that knows the api's base URL and how to attach a token; every
// call to the API goes through here instead of using package:http directly.
// lesson: frontend.l4.backend-for-frontend
// From stage-4 this is only the transport every feature shares: the URL,
// the token header and what an error looks like. Which requests exist, and
// the models they return, belong to the features: catalog_api.dart in
// features/catalog/, orders_api.dart in features/ordering/.
class ApiClient {
  // Caddy proxies /api/v1/* to DonHang.Api (see ../../../Caddyfile); this app
  // is served by a different container (app-web:8081) so it always goes
  // through Caddy on :8080, never straight to the api container.
  static const String baseUrl = 'http://localhost:8080/api/v1';

  // lesson: frontend.l2.notifier-for-app-state
  // No token field of its own: every request asks for the current token,
  // whose only copy is in authProvider (see ordersApiProvider).
  final String? Function() readToken;

  // From stage-3 a test can hand in a fake http.Client (package:http/testing.dart).
  final http.Client _http;

  ApiClient({this.readToken = _noToken, http.Client? httpClient}) : _http = httpClient ?? http.Client();

  static String? _noToken() => null;

  Map<String, String> get _headers {
    final token = readToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // A GET with no headers for what any visitor may read, such as products;
  // with the token when the answer depends on who asks, such as an order.
  Future<http.Response> get(String path, {bool signedIn = false}) =>
      _http.get(Uri.parse('$baseUrl$path'), headers: signedIn ? _headers : null);

  // A POST of [body] as JSON, with the token and any [headers] of its own.
  Future<http.Response> post(String path, Object? body, {Map<String, String> headers = const {}}) =>
      _http.post(Uri.parse('$baseUrl$path'), headers: {..._headers, ...headers}, body: jsonEncode(body));
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

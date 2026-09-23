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

  String? _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<List<Product>> fetchProducts() async {
    final response = await http.get(Uri.parse('$baseUrl/products'));
    if (response.statusCode != 200) {
      throw Exception('failed to load products (${response.statusCode})');
    }
    final items = jsonDecode(response.body) as List<dynamic>;
    return items.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();
  }

  // lesson: frontend.l1.logging-in-from-the-app
  Future<String> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (response.statusCode != 200) {
      throw Exception('login failed (${response.statusCode})');
    }
    final token = (jsonDecode(response.body) as Map<String, dynamic>)['token'] as String;
    _token = token;
    return token;
  }

  // lesson: frontend.l1.creating-an-order
  Future<OrderResult> createOrder(List<OrderItemRequest> items) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders'),
      headers: _headers,
      body: jsonEncode({'items': items.map((item) => item.toJson()).toList()}),
    );
    if (response.statusCode != 201) {
      throw Exception('failed to create order (${response.statusCode})');
    }
    return OrderResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

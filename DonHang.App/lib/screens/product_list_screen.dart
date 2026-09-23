import 'package:flutter/material.dart';
import '../api_client.dart';
import '../models.dart';
import 'login_screen.dart';

// lesson: frontend.l1.futurebuilder-loading-error-empty
// lesson: frontend.l1.stateless-vs-stateful
class ProductListScreen extends StatefulWidget {
  final ApiClient apiClient;

  const ProductListScreen({super.key, required this.apiClient});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late Future<List<Product>> _products;

  @override
  void initState() {
    super.initState();
    _products = widget.apiClient.fetchProducts();
  }

  // lesson: frontend.l1.setstate-and-rebuilding
  void _reload() => setState(() => _products = widget.apiClient.fetchProducts());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn Hàng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.login),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => LoginScreen(apiClient: widget.apiClient)),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Product>>(
        future: _products,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Could not load products: ${snapshot.error}'));
          }
          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return const Center(child: Text('No products yet.'));
          }
          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                title: Text(product.name),
                trailing: Text('${product.priceVnd} đ'),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _reload, child: const Icon(Icons.refresh)),
    );
  }
}

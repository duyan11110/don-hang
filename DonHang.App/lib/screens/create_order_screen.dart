import 'package:flutter/material.dart';
import '../api_client.dart';
import '../models.dart';

// lesson: frontend.l1.creating-an-order
// A fixed single line (product 1, quantity 1): GĐ1 proves the round trip
// works, not a full cart — that is out of scope here.
class CreateOrderScreen extends StatefulWidget {
  final ApiClient apiClient;

  const CreateOrderScreen({super.key, required this.apiClient});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  String? _result;
  bool _loading = false;

  Future<void> _placeOrder() async {
    setState(() => _loading = true);
    try {
      final order = await widget.apiClient.createOrder([
        OrderItemRequest(productId: 1, quantity: 1, unitPriceVnd: 1250000),
      ]);
      setState(() => _result = 'Order ${order.id} placed, status ${order.status}');
    } catch (e) {
      setState(() => _result = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Place an order')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: _loading ? null : _placeOrder,
              child: _loading ? const CircularProgressIndicator() : const Text('Order 1 keyboard'),
            ),
            if (_result != null) Padding(padding: const EdgeInsets.all(16), child: Text(_result!)),
          ],
        ),
      ),
    );
  }
}

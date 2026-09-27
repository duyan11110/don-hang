import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api_client.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../providers.dart';

// One product and one quantity per order: a cart with several lines is
// outside stage-2 (frontend.l2.form-validation depth_notes).
class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

// lesson: frontend.l2.form-validation
// The key reaches the Form's state from the submit button. Each validator
// returns an error message, or null when the value is fine.
class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');
  Product? _product;
  String? _serverError;
  bool _sending = false;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  String? _checkProduct(Product? product) =>
      product == null ? AppLocalizations.of(context).productRequired : null;

  String? _checkQuantity(String? text) {
    final quantity = int.tryParse(text ?? '');
    return quantity == null || quantity < 1 ? AppLocalizations.of(context).quantityInvalid : null;
  }

  // lesson: frontend.l2.form-validation
  // lesson: frontend.l2.server-errors-in-forms
  // validate() runs every validator first; only a valid form is sent. When
  // the API still says no, its `detail` is shown and every field keeps what
  // the customer entered, so one value can be fixed and the order sent again.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _serverError = null;
    });
    try {
      final product = _product!;
      final quantity = int.parse(_quantityController.text);
      final order = await ref.read(apiClientProvider).createOrder([
        OrderItemRequest(productId: product.id, quantity: quantity, unitPriceVnd: product.priceVnd),
      ]);
      if (mounted) context.go('/orders/${order.id}');
    } on ApiProblem catch (problem) {
      if (mounted) setState(() => _serverError = problem.detail);
    } on Exception {
      if (mounted) setState(() => _serverError = AppLocalizations.of(context).orderFailed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final products = ref.watch(productsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.placeOrder)),
      body: products.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(l10n.productsLoadError)),
        data: (items) => _form(context, items),
      ),
    );
  }

  // lesson: frontend.l2.form-validation
  // lesson: frontend.l2.server-errors-in-forms
  Widget _form(BuildContext context, List<Product> products) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<Product>(
            initialValue: _product,
            decoration: InputDecoration(labelText: l10n.productLabel),
            items: [for (final p in products) DropdownMenuItem(value: p, child: Text(p.name))],
            onChanged: (product) => _product = product,
            validator: _checkProduct,
          ),
          TextFormField(
            controller: _quantityController,
            decoration: InputDecoration(labelText: l10n.quantityLabel),
            keyboardType: TextInputType.number,
            validator: _checkQuantity,
          ),
          const SizedBox(height: 16),
          if (_serverError != null)
            Text(_serverError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 8),
          FilledButton(onPressed: _sending ? null : _submit, child: Text(l10n.submitOrder)),
        ],
      ),
    );
  }
}

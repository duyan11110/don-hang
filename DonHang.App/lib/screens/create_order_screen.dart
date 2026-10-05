import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api_client.dart';
import '../auth/auth_controller.dart';
import '../auth/token_subject.dart';
import '../design/components/loading_view.dart';
import '../design/components/message_view.dart';
import '../design/components/status_banner.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../offline/order_queue.dart';
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
  // lesson: frontend.l3.offline-order-queue
  // From stage-3 the key is made here, once per order the customer means to
  // place, and no answer from the API puts the order in the offline queue.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _serverError = null;
    });
    final product = _product!;
    final quantity = int.parse(_quantityController.text);
    final items = [OrderItemRequest(productId: product.id, quantity: quantity, unitPriceVnd: product.priceVnd)];
    final idempotencyKey = newIdempotencyKey();
    try {
      final order = await ref.read(apiClientProvider).createOrder(items, idempotencyKey: idempotencyKey);
      if (mounted) context.go('/orders/${order.id}');
    } on ApiUnreachable {
      _queue('$quantity × ${product.name}', items, idempotencyKey);
    } on ApiProblem catch (problem) {
      if (mounted) setState(() => _serverError = problem.detail);
    } on Exception {
      if (mounted) setState(() => _serverError = AppLocalizations.of(context).orderFailed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // lesson: frontend.l3.offline-order-queue
  // The order waits on the device with the key it was just sent with: if
  // that attempt did reach the API, the next one gets the same order back.
  // It is not placed yet, so the customer sees it among the waiting orders.
  void _queue(String description, List<OrderItemRequest> items, String idempotencyKey) {
    final token = ref.read(authProvider);
    final subject = token == null ? null : tokenSubject(token);
    if (!mounted) return;
    if (subject == null) {
      setState(() => _serverError = AppLocalizations.of(context).orderFailed);
      return;
    }
    ref.read(orderQueueProvider.notifier).add(QueuedOrder(
          idempotencyKey: idempotencyKey,
          subject: subject,
          description: description,
          items: items,
        ));
    context.go('/orders/queued');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final products = ref.watch(productsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.placeOrder)),
      body: products.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => MessageView(message: l10n.productsLoadError),
        data: (loaded) => _form(context, loaded.items),
      ),
    );
  }

  // lesson: frontend.l2.form-validation
  // lesson: frontend.l2.server-errors-in-forms
  // lesson: frontend.l3.semantic-tokens
  // lesson: frontend.l3.component-library
  // From stage-3 spacing comes from tokens and the server's error is a
  // StatusBanner in the error tone, like every other status in the app.
  Widget _form(BuildContext context, List<Product> products) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        padding: Insets.screen,
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
          const SizedBox(height: Space.lg),
          if (_serverError != null) StatusBanner(message: _serverError!, tone: StatusTone.error),
          const SizedBox(height: Space.sm),
          FilledButton(onPressed: _sending ? null : _submit, child: Text(l10n.submitOrder)),
        ],
      ),
    );
  }
}

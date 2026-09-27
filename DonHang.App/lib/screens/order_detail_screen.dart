import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers.dart';

// lesson: frontend.l2.route-guards
// Reached only through /orders/:id, which the router's redirect guards: a
// signed-out visitor is sent to /login before this screen is built. The API
// still checks the token itself (401) and who owns the order (403).
class OrderDetailScreen extends ConsumerWidget {
  final int id;

  const OrderDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final order = ref.watch(orderProvider(id));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.orderTitle(id))),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(l10n.orderLoadError)),
        data: (order) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l10n.orderStatus(order.status)),
        ),
      ),
    );
  }
}

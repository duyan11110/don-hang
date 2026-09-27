import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../providers.dart';

// lesson: frontend.l2.deep-links
// Gets only the id from the URL and loads the product itself: opened from a
// link, there is no list screen before it to hand over a Product.
class ProductDetailScreen extends ConsumerWidget {
  final int id;

  const ProductDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final product = ref.watch(productProvider(id));
    return Scaffold(
      appBar: AppBar(title: Text(product.value?.name ?? '')),
      body: product.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(l10n.productLoadError)),
        data: (product) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.name, style: Theme.of(context).textTheme.headlineSmall),
              Text(l10n.productPrice(product.priceVnd)),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => context.go('/orders/new'), child: Text(l10n.placeOrder)),
            ],
          ),
        ),
      ),
    );
  }
}

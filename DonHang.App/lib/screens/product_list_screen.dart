import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../widgets/product_catalog.dart';

// lesson: frontend.l2.riverpod-providers
// lesson: frontend.l2.futureprovider-and-asyncvalue
// lesson: frontend.l2.overriding-providers-in-tests
// No State class and no constructor parameters: everything it shows comes
// from providers, and AsyncValue.when gives one builder per case.
class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final products = ref.watch(productsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle), actions: _actions(context, ref)),
      body: products.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(l10n.productsLoadError)),
        data: (items) => items.isEmpty
            ? Center(child: Text(l10n.noProducts))
            : ProductCatalog(
                products: items,
                onProductTap: (product) => context.go('/products/${product.id}'),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.reload,
        onPressed: () => ref.invalidate(productsProvider),
        child: const Icon(Icons.refresh),
      ),
    );
  }

  // lesson: frontend.l2.notifier-for-app-state
  // lesson: frontend.l2.routes-with-go-router
  // Watching authProvider rebuilds this screen when the token changes, so the
  // button switches between sign-in and sign-out. onPressed only reads.
  List<Widget> _actions(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(authProvider) != null;
    return [
      IconButton(
        icon: const Icon(Icons.add_shopping_cart),
        tooltip: l10n.placeOrder,
        onPressed: () => context.go('/orders/new'),
      ),
      if (signedIn)
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: l10n.signOut,
          onPressed: () => ref.read(authProvider.notifier).signOut(),
        )
      else
        IconButton(icon: const Icon(Icons.login), tooltip: l10n.signIn, onPressed: () => context.go('/login')),
    ];
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../design/components/loading_view.dart';
import '../design/components/message_view.dart';
import '../design/components/status_banner.dart';
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

  // lesson: frontend.l3.rebuild-scope
  // lesson: frontend.l3.offline-first
  // From stage-3 this build does not watch authProvider: signing in or out
  // rebuilds only SignInOutButton, never ProductCatalog and its tiles. A
  // saved list the API could not refresh is shown with a warning above it.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final products = ref.watch(productsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle), actions: _actions(context)),
      body: products.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => MessageView(message: l10n.productsLoadError),
        data: (loaded) => Column(
          children: [
            if (loaded.outOfDate) StatusBanner(message: l10n.savedListBanner, tone: StatusTone.warning),
            Expanded(child: _catalog(context, loaded)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.reload,
        onPressed: () => ref.invalidate(productsProvider),
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _catalog(BuildContext context, LoadedProducts loaded) {
    if (loaded.items.isEmpty) return MessageView(message: AppLocalizations.of(context).noProducts);
    return ProductCatalog(
      products: loaded.items,
      onProductTap: (product) => context.go('/products/${product.id}'),
    );
  }

  List<Widget> _actions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      IconButton(
        icon: const Icon(Icons.schedule_send),
        tooltip: l10n.queuedOrdersTitle,
        onPressed: () => context.go('/orders/queued'),
      ),
      IconButton(
        icon: const Icon(Icons.add_shopping_cart),
        tooltip: l10n.placeOrder,
        onPressed: () => context.go('/orders/new'),
      ),
      const SignInOutButton(),
    ];
  }
}

// lesson: frontend.l3.rebuild-scope
// lesson: frontend.l2.notifier-for-app-state
// The one widget on this screen that depends on the token, so the one that
// watches authProvider: a change of token rebuilds this button only.
// onPressed only reads.
class SignInOutButton extends ConsumerWidget {
  const SignInOutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(authProvider) != null;
    if (signedIn) {
      return IconButton(
        icon: const Icon(Icons.logout),
        tooltip: l10n.signOut,
        onPressed: () => ref.read(authProvider.notifier).signOut(),
      );
    }
    return IconButton(icon: const Icon(Icons.login), tooltip: l10n.signIn, onPressed: () => context.go('/login'));
  }
}

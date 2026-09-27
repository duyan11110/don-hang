import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_controller.dart';
import 'screens/auth_callback_screen.dart';
import 'screens/create_order_screen.dart';
import 'screens/login_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/product_list_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // lesson: frontend.l2.route-guards
  // go_router re-runs `redirect` when a Listenable changes; Riverpod tells
  // us when authProvider changes. This ValueNotifier joins the two.
  final authChanges = ValueNotifier<String?>(ref.read(authProvider));
  ref.listen(authProvider, (_, token) => authChanges.value = token);
  ref.onDispose(authChanges.dispose);

  final router = GoRouter(
    refreshListenable: authChanges,
    // Runs before every navigation, a typed URL included. Returning a path
    // sends the user there; returning null keeps the requested location.
    redirect: (context, state) {
      final signedIn = ref.read(authProvider) != null;
      if (!signedIn && state.matchedLocation.startsWith('/orders')) {
        return '/login';
      }
      return null;
    },
    routes: _routes,
  );
  ref.onDispose(router.dispose);
  return router;
});

// lesson: frontend.l2.routes-with-go-router
// lesson: frontend.l2.deep-links
// Every screen of the app, each with its path. The children of `/` are
// built on top of the product list, so their back arrow leads to it.
// `orders/new` comes before `orders/:id`, or `new` would be read as an id.
final List<RouteBase> _routes = [
  GoRoute(
    path: '/',
    builder: (context, state) => const ProductListScreen(),
    routes: [
      GoRoute(
        path: 'products/:id',
        builder: (context, state) => ProductDetailScreen(id: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: 'orders/new', builder: (context, state) => const CreateOrderScreen()),
      GoRoute(
        path: 'orders/:id',
        builder: (context, state) => OrderDetailScreen(id: int.parse(state.pathParameters['id']!)),
      ),
    ],
  ),
  GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
  // Where Keycloak sends the browser back: /auth/callback?code=…&state=…
  GoRoute(
    path: '/auth/callback',
    builder: (context, state) => AuthCallbackScreen(
      code: state.uri.queryParameters['code'],
      oauthState: state.uri.queryParameters['state'],
    ),
  ),
];

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'design/brand.dart';
import 'design/theme.dart';
import 'l10n/app_localizations.dart';
import 'offline/queue_sync.dart';
import 'router.dart';

// lesson: frontend.l2.riverpod-providers
// lesson: frontend.l2.deep-links
// ProviderScope keeps the value of every provider the app reads.
// usePathUrlStrategy() makes URLs plain paths (/products/3, not /#/products/3);
// the app-web server answers every such path with index.html.
void main() {
  usePathUrlStrategy();
  runApp(const ProviderScope(child: DonHangApp()));
}

// lesson: frontend.l2.routes-with-go-router
// lesson: frontend.l2.dark-mode
// lesson: frontend.l2.localizing-with-arb
// The router decides which screen shows; both themes grow from one seed;
// the text comes from the ARB file of the browser's language.
// lesson: frontend.l3.brand-themes
// From stage-3 both themes come from buildTheme and one Brand. Listening
// to queueSyncProvider starts the offline queue's sync when the app starts,
// without rebuilding the app each time the sync's state changes.
class DonHangApp extends ConsumerWidget {
  const DonHangApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(queueSyncProvider, (previous, next) {});
    return MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildTheme(donHangBrand, Brightness.light),
      darkTheme: buildTheme(donHangBrand, Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

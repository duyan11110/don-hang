import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'l10n/app_localizations.dart';
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
class DonHangApp extends ConsumerWidget {
  const DonHangApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

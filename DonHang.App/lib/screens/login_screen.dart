import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../l10n/app_localizations.dart';

// From stage-2 there is no password here: the button leaves for Keycloak's
// sign-in page, and the customer comes back through /auth/callback.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.signIn)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.signInExplanation, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.read(authProvider.notifier).signIn(),
                child: Text(l10n.signInWithKeycloak),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

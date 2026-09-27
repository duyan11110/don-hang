import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../l10n/app_localizations.dart';

// The other end of the sign-in that LoginScreen starts.
// Keycloak sends the browser back to /auth/callback?code=…: the app starts
// fresh at that URL and the route hands the query parameters to this screen,
// which finishes signing in and moves on to the product list.
class AuthCallbackScreen extends ConsumerStatefulWidget {
  final String? code;
  final String? oauthState;

  const AuthCallbackScreen({super.key, required this.code, required this.oauthState});

  @override
  ConsumerState<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends ConsumerState<AuthCallbackScreen> {
  late bool _failed = widget.code == null;

  @override
  void initState() {
    super.initState();
    if (!_failed) _finish(widget.code!);
  }

  Future<void> _finish(String code) async {
    try {
      await ref.read(authProvider.notifier).completeSignIn(code: code, oauthState: widget.oauthState);
      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _failed
              ? [
                  Text(l10n.signInFailed),
                  TextButton(onPressed: () => context.go('/login'), child: Text(l10n.tryAgain)),
                ]
              : [const CircularProgressIndicator(), const SizedBox(height: 16), Text(l10n.signingIn)],
        ),
      ),
    );
  }
}

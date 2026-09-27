import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'keycloak_sign_in.dart';

// lesson: frontend.l2.notifier-for-app-state
// lesson: frontend.l2.route-guards
// The signed-in customer's access token, or null when nobody is signed in.
// Only these methods change it, by assigning `state`; every widget watching
// authProvider then rebuilds. Kept in memory only, as at stage-1: reloading
// the page signs the customer out.
class AuthController extends Notifier<String?> {
  @override
  String? build() => null;

  // Leaves the app for Keycloak's sign-in page; nothing changes here yet.
  void signIn() => KeycloakSignIn.start();

  // Called on /auth/callback with what Keycloak put in the URL.
  Future<void> completeSignIn({required String code, required String? oauthState}) async {
    state = await KeycloakSignIn.finish(code: code, state: oauthState);
  }

  void signOut() => state = null;
}

final authProvider = NotifierProvider<AuthController, String?>(AuthController.new);

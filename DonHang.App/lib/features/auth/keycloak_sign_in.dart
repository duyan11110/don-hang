import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'browser.dart';

// Plumbing the frontend lessons do not teach (frontend.l2.notifier-for-app-state
// depth_notes): the authorization code flow with PKCE from
// backend.l2.authorization-code-flow, done by the app itself in the browser.
// scripts/lib/keycloak.sh does the same steps with curl.
class KeycloakSignIn {
  static const String realmUrl = 'http://localhost:8180/realms/donhang';
  static const String clientId = 'donhang-app';
  static const String redirectUri = 'http://localhost:8081/auth/callback';

  static const String _verifierKey = 'donhang.pkce_verifier';
  static const String _stateKey = 'donhang.oauth_state';

  // Sends the browser to Keycloak's sign-in page. The code_verifier and
  // state must outlive this page, so they wait in the tab's sessionStorage.
  static void start() {
    final verifier = _randomToken();
    final state = _randomToken();
    saveForRedirect(_verifierKey, verifier);
    saveForRedirect(_stateKey, state);
    goTo(authorizeUrl(verifier: verifier, state: state));
  }

  // The URL start() opens; separate so a test or script can print it.
  static Uri authorizeUrl({required String verifier, required String state}) {
    final challenge = base64UrlEncode(sha256.convert(ascii.encode(verifier)).bytes).replaceAll('=', '');
    return Uri.parse('$realmUrl/protocol/openid-connect/auth').replace(queryParameters: {
      'client_id': clientId,
      'response_type': 'code',
      'scope': 'openid',
      'redirect_uri': redirectUri,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
    });
  }

  // Back at /auth/callback?code=…&state=…: checks the state this tab saved,
  // then trades the code and the verifier for tokens. Only the access token
  // is kept; there is no refresh, so after its 5 minutes the customer signs
  // in again (Keycloak remembers them, so without typing a password).
  static Future<String> finish({required String code, required String? state}) async {
    final verifier = takeSaved(_verifierKey);
    final expectedState = takeSaved(_stateKey);
    if (verifier == null || state == null || state != expectedState) {
      throw StateError('this sign-in was not started in this browser tab');
    }
    final response = await http.post(
      Uri.parse('$realmUrl/protocol/openid-connect/token'),
      body: {
        'grant_type': 'authorization_code',
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'code': code,
        'code_verifier': verifier,
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Keycloak refused the code (${response.statusCode})');
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['access_token'] as String;
  }

  // 32 random bytes as base64url without padding: 43 characters, all of
  // them allowed in a PKCE code_verifier.
  static String _randomToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

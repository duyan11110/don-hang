import 'package:web/web.dart' as web;

// sessionStorage belongs to this browser tab and survives the trip to
// Keycloak and back, which memory does not: the app starts fresh on return.
void saveForRedirect(String key, String value) => web.window.sessionStorage.setItem(key, value);

// Reads a saved value once and deletes it, so a sign-in cannot be replayed.
String? takeSaved(String key) {
  final value = web.window.sessionStorage.getItem(key);
  web.window.sessionStorage.removeItem(key);
  return value;
}

// Leaves the app: the whole page goes to [url].
void goTo(Uri url) => web.window.location.assign(url.toString());

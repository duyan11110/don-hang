import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'local_store.dart';

LocalStore createLocalStore() => BrowserLocalStore();

class BrowserLocalStore implements LocalStore {
  @override
  String? read(String key) => web.window.localStorage.getItem(key);

  @override
  void write(String key, String value) => web.window.localStorage.setItem(key, value);

  @override
  void remove(String key) => web.window.localStorage.removeItem(key);
}

// Calls [onOnline] each time the browser says a network is back, and
// returns the function that stops listening. "Online" only means a network
// is there; whether the API answers is found out by sending.
void Function() listenForOnline(void Function() onOnline) {
  final listener = ((web.Event _) => onOnline()).toJS;
  web.window.addEventListener('online', listener);
  return () => web.window.removeEventListener('online', listener);
}

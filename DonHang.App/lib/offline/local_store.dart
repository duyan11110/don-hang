import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'browser.dart';

// lesson: frontend.l3.offline-first
// String values by key, kept on this device. In the browser it is
// localStorage: one store per site, still there after a page reload or
// after the tab is closed, limited in size by the browser. Nothing secret
// goes in it: no token, only what any visitor may see.
abstract class LocalStore {
  String? read(String key);
  void write(String key, String value);
  void remove(String key);
}

// Where there is no browser (widget tests), or as a test's own store: the
// same three operations on a Map, gone when the test ends.
class MemoryLocalStore implements LocalStore {
  final Map<String, String> values = {};

  @override
  String? read(String key) => values[key];

  @override
  void write(String key, String value) => values[key] = value;

  @override
  void remove(String key) => values.remove(key);
}

// The browser's localStorage when the app runs on the web, a
// MemoryLocalStore elsewhere; tests override it with their own.
final localStoreProvider = Provider<LocalStore>((ref) => createLocalStore());

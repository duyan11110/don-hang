// Plumbing, as in auth/browser.dart: what the offline code needs from the
// browser. On the web these are the real localStorage and `online` event;
// in `flutter test`, which runs without a browser, the stub stands in.
export 'browser_stub.dart' if (dart.library.js_interop) 'browser_web.dart';

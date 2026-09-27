// Plumbing, not a lesson: the two things sign-in needs from the browser.
// On the web these are the real browser; in `flutter test`, which runs
// without a browser, the stub below stands in and refuses to be used.
export 'browser_stub.dart' if (dart.library.js_interop) 'browser_web.dart';

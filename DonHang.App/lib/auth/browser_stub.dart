// Used where there is no browser (widget tests). DonHang.App runs only on
// the web, so signing in anywhere else is a mistake worth failing loudly.
void saveForRedirect(String key, String value) => throw UnsupportedError('sign-in needs a browser');

String? takeSaved(String key) => throw UnsupportedError('sign-in needs a browser');

void goTo(Uri url) => throw UnsupportedError('sign-in needs a browser');

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Đơn Hàng';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get signInWithKeycloak => 'Sign in with Keycloak';

  @override
  String get signInExplanation =>
      'You sign in on Keycloak\'s page, then come back here.';

  @override
  String get signingIn => 'Signing you in…';

  @override
  String get signInFailed => 'Sign-in did not finish.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get reload => 'Reload';

  @override
  String get productsLoadError => 'Could not load products.';

  @override
  String get noProducts => 'No products yet.';

  @override
  String get productLoadError => 'Could not load this product.';

  @override
  String productPrice(int price) {
    final intl.NumberFormat priceNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return '$priceString VND';
  }

  @override
  String productSemanticsLabel(String name, int price) {
    final intl.NumberFormat priceNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return '$name, $priceString dong';
  }

  @override
  String get placeOrder => 'Place an order';

  @override
  String get productLabel => 'Product';

  @override
  String get productRequired => 'Choose a product.';

  @override
  String get quantityLabel => 'Quantity';

  @override
  String get quantityInvalid => 'Enter a whole number, 1 or more.';

  @override
  String get submitOrder => 'Place order';

  @override
  String get orderFailed =>
      'The order could not be sent. Check your connection and try again.';

  @override
  String orderTitle(int id) {
    return 'Order $id';
  }

  @override
  String orderStatus(String status) {
    return 'Status: $status';
  }

  @override
  String get orderLoadError => 'Could not load this order.';

  @override
  String get savedListBanner =>
      'Showing the saved list: the API did not answer, so it may be out of date.';

  @override
  String get queuedOrdersTitle => 'Waiting orders';

  @override
  String get queueEmpty => 'No orders are waiting.';

  @override
  String get sendNow => 'Send now';

  @override
  String queuedWaiting(String description) {
    return 'Waiting to be sent: $description';
  }

  @override
  String queuedSent(int id, String description) {
    return 'Placed as order $id: $description';
  }

  @override
  String queuedPriceChanged(int id, int seen, int charged) {
    final intl.NumberFormat seenNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String seenString = seenNumberFormat.format(seen);
    final intl.NumberFormat chargedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String chargedString = chargedNumberFormat.format(charged);

    return 'Placed as order $id, but the price changed: you saw $seenString VND, the order costs $chargedString VND.';
  }

  @override
  String queuedRejected(String description, String problem) {
    return 'Not placed: $description. $problem';
  }

  @override
  String get remove => 'Remove';

  @override
  String get openOrder => 'Open';

  @override
  String get syncNotSent =>
      'Not sent yet: the API did not take them. They wait here until the next try.';

  @override
  String get syncRateLimited =>
      'The API asked the app to wait before sending more orders.';

  @override
  String syncRateLimitedUntil(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.Hm(localeName);
    final String timeString = timeDateFormat.format(time);

    return 'The API asked the app to wait: the next try is after $timeString.';
  }

  @override
  String get syncSignInNeeded => 'Sign in again to send these orders.';
}

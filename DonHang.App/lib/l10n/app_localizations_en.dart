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
}

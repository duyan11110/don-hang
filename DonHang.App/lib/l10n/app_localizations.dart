import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// The app's name, in the title bar and the browser tab.
  ///
  /// In en, this message translates to:
  /// **'Đơn Hàng'**
  String get appTitle;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signInWithKeycloak.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Keycloak'**
  String get signInWithKeycloak;

  /// No description provided for @signInExplanation.
  ///
  /// In en, this message translates to:
  /// **'You sign in on Keycloak\'s page, then come back here.'**
  String get signInExplanation;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing you in…'**
  String get signingIn;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in did not finish.'**
  String get signInFailed;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @productsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load products.'**
  String get productsLoadError;

  /// No description provided for @noProducts.
  ///
  /// In en, this message translates to:
  /// **'No products yet.'**
  String get noProducts;

  /// No description provided for @productLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load this product.'**
  String get productLoadError;

  /// A product's price in Vietnamese dong.
  ///
  /// In en, this message translates to:
  /// **'{price} VND'**
  String productPrice(int price);

  /// What a screen reader says for one product: its name, then its price.
  ///
  /// In en, this message translates to:
  /// **'{name}, {price} dong'**
  String productSemanticsLabel(String name, int price);

  /// No description provided for @placeOrder.
  ///
  /// In en, this message translates to:
  /// **'Place an order'**
  String get placeOrder;

  /// No description provided for @productLabel.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get productLabel;

  /// No description provided for @productRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a product.'**
  String get productRequired;

  /// No description provided for @quantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantityLabel;

  /// No description provided for @quantityInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number, 1 or more.'**
  String get quantityInvalid;

  /// No description provided for @submitOrder.
  ///
  /// In en, this message translates to:
  /// **'Place order'**
  String get submitOrder;

  /// No description provided for @orderFailed.
  ///
  /// In en, this message translates to:
  /// **'The order could not be sent. Check your connection and try again.'**
  String get orderFailed;

  /// Title of one order's screen; id is the order number, shown as is.
  ///
  /// In en, this message translates to:
  /// **'Order {id}'**
  String orderTitle(int id);

  /// The order's status as the API sends it, such as pending.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String orderStatus(String status);

  /// No description provided for @orderLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load this order.'**
  String get orderLoadError;

  /// Above the product list when it is the copy saved on this device and loading a fresh one failed.
  ///
  /// In en, this message translates to:
  /// **'Showing the saved list: the API did not answer, so it may be out of date.'**
  String get savedListBanner;

  /// Title of the screen listing orders placed while the API could not be reached.
  ///
  /// In en, this message translates to:
  /// **'Waiting orders'**
  String get queuedOrdersTitle;

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No orders are waiting.'**
  String get queueEmpty;

  /// Button that sends the waiting orders at once.
  ///
  /// In en, this message translates to:
  /// **'Send now'**
  String get sendNow;

  /// An order kept on this device; it has no order number yet.
  ///
  /// In en, this message translates to:
  /// **'Waiting to be sent: {description}'**
  String queuedWaiting(String description);

  /// No description provided for @queuedSent.
  ///
  /// In en, this message translates to:
  /// **'Placed as order {id}: {description}'**
  String queuedSent(int id, String description);

  /// A waiting order was sent and the API charged the current price, not the saved one.
  ///
  /// In en, this message translates to:
  /// **'Placed as order {id}, but the price changed: you saw {seen} VND, the order costs {charged} VND.'**
  String queuedPriceChanged(int id, int seen, int charged);

  /// The API refused a waiting order; problem is the API's own detail.
  ///
  /// In en, this message translates to:
  /// **'Not placed: {description}. {problem}'**
  String queuedRejected(String description, String problem);

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @openOrder.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openOrder;

  /// No description provided for @syncNotSent.
  ///
  /// In en, this message translates to:
  /// **'Not sent yet: the API did not take them. They wait here until the next try.'**
  String get syncNotSent;

  /// No description provided for @syncRateLimited.
  ///
  /// In en, this message translates to:
  /// **'The API asked the app to wait before sending more orders.'**
  String get syncRateLimited;

  /// No description provided for @syncRateLimitedUntil.
  ///
  /// In en, this message translates to:
  /// **'The API asked the app to wait: the next try is after {time}.'**
  String syncRateLimitedUntil(DateTime time);

  /// No description provided for @syncSignInNeeded.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to send these orders.'**
  String get syncSignInNeeded;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

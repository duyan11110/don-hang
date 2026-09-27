// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Đơn Hàng';

  @override
  String get signIn => 'Đăng nhập';

  @override
  String get signOut => 'Đăng xuất';

  @override
  String get signInWithKeycloak => 'Đăng nhập bằng Keycloak';

  @override
  String get signInExplanation =>
      'Bạn đăng nhập trên trang của Keycloak rồi quay lại đây.';

  @override
  String get signingIn => 'Đang đăng nhập…';

  @override
  String get signInFailed => 'Đăng nhập chưa hoàn tất.';

  @override
  String get tryAgain => 'Thử lại';

  @override
  String get reload => 'Tải lại';

  @override
  String get productsLoadError => 'Không tải được danh sách sản phẩm.';

  @override
  String get noProducts => 'Chưa có sản phẩm nào.';

  @override
  String get productLoadError => 'Không tải được sản phẩm này.';

  @override
  String productPrice(int price) {
    final intl.NumberFormat priceNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return '$priceString đ';
  }

  @override
  String productSemanticsLabel(String name, int price) {
    final intl.NumberFormat priceNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return '$name, $priceString đồng';
  }

  @override
  String get placeOrder => 'Đặt hàng';

  @override
  String get productLabel => 'Sản phẩm';

  @override
  String get productRequired => 'Hãy chọn một sản phẩm.';

  @override
  String get quantityLabel => 'Số lượng';

  @override
  String get quantityInvalid => 'Nhập một số nguyên từ 1 trở lên.';

  @override
  String get submitOrder => 'Gửi đơn';

  @override
  String get orderFailed =>
      'Chưa gửi được đơn. Hãy kiểm tra kết nối rồi thử lại.';

  @override
  String orderTitle(int id) {
    return 'Đơn $id';
  }

  @override
  String orderStatus(String status) {
    return 'Trạng thái: $status';
  }

  @override
  String get orderLoadError => 'Không tải được đơn hàng này.';
}

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

  @override
  String get savedListBanner =>
      'Đang hiện danh sách đã lưu: API không trả lời nên có thể đã cũ.';

  @override
  String get queuedOrdersTitle => 'Đơn đang chờ';

  @override
  String get queueEmpty => 'Không có đơn nào đang chờ.';

  @override
  String get sendNow => 'Gửi ngay';

  @override
  String queuedWaiting(String description) {
    return 'Đang chờ gửi: $description';
  }

  @override
  String queuedSent(int id, String description) {
    return 'Đã đặt thành đơn $id: $description';
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

    return 'Đã đặt thành đơn $id, nhưng giá đã đổi: bạn thấy $seenString đ, đơn có giá $chargedString đ.';
  }

  @override
  String queuedRejected(String description, String problem) {
    return 'Chưa đặt được: $description. $problem';
  }

  @override
  String get remove => 'Xóa';

  @override
  String get openOrder => 'Mở';

  @override
  String get syncNotSent =>
      'Chưa gửi được: API chưa nhận. Các đơn chờ ở đây tới lần thử sau.';

  @override
  String get syncRateLimited => 'API yêu cầu app chờ rồi mới gửi thêm đơn.';

  @override
  String syncRateLimitedUntil(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.Hm(localeName);
    final String timeString = timeDateFormat.format(time);

    return 'API yêu cầu app chờ: lần thử sau là sau $timeString.';
  }

  @override
  String get syncSignInNeeded => 'Hãy đăng nhập lại để gửi các đơn này.';
}

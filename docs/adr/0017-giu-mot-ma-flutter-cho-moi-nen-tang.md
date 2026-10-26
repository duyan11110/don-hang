# 0017. Giữ một mã Flutter cho mọi nền tảng

Trạng thái: Đã chấp nhận
Ngày: đề xuất giữa Sprint 20, quyết định cuối Sprint 20
Người quyết định: trưởng nhóm, cùng product owner
Hạn góp ý: hết thứ Sáu tuần thứ hai Sprint 20

### Bối cảnh

Đơn Hàng sẽ phục vụ 1.000 cửa hàng từ một bản triển khai chung (ADR 0012).
Khách của các cửa hàng đặt hàng chủ yếu từ trình duyệt trên điện thoại; vài
cửa hàng đã hỏi có app cài trên máy không; một số cửa hàng muốn trang sản phẩm
của mình tìm được qua máy tìm kiếm (cả ba là giả định từ các buổi nói chuyện
với cửa hàng, chưa có số đo).

Ở stage-3, DonHang.App là một mã Flutter (Dart) chỉ có thư mục nền tảng
`web/`: nó chỉ được build cho trình duyệt. Design system (`lib/design/`, mỗi
cửa hàng khác nhau ở giá trị `Brand` trong `lib/design/brand.dart`), hàng đợi
đơn offline và phần đăng nhập đều viết bằng Dart, không phụ thuộc trình duyệt
trừ hai file `browser_web.dart` bọc các API của trình duyệt. Một đội làm cả
backend lẫn app.

### Các phương án

- Giữ một mã Flutter: web như bây giờ, Android và iOS build từ cùng mã khi có
  cửa hàng cần app cài trên máy (thêm thư mục nền tảng, viết lại phần trong
  hai file `browser_web.dart` cho nền tảng đó). Design system, `Brand`, hàng
  đợi offline và test dùng chung cho mọi nền tảng.
- Viết lại client web bằng một framework web dựng HTML, và làm app native
  riêng cho từng nền tảng khi cần: mỗi client hợp nhất với nền tảng của nó,
  trang web có sẵn HTML cho máy tìm kiếm. Nhưng design system, `Brand` và hàng
  đợi offline phải viết lại và giữ đồng bộ ở hai tới ba nơi, bằng hai tới ba
  ngôn ngữ, với một đội.
- App native cho từng nền tảng di động, giữ Flutter cho web: trình duyệt vẫn
  là nơi khách đặt nhiều nhất nên Flutter web vẫn phải giữ, cộng thêm hai mã
  native; cùng chi phí giữ đồng bộ như phương án trên.

### Quyết định

Chọn giữ một mã Flutter cho mọi nền tảng. Với một đội, giá trị lớn nhất là
một design system, một hàng đợi offline và một bộ test; mỗi cửa hàng vẫn chỉ
khác nhau ở giá trị `Brand`, trên nền tảng nào cũng vậy. Stage-4 không thêm
thư mục `android/` hay `ios/`: chưa cửa hàng nào cần app cài trên máy đủ để
đội trả chi phí phát hành lên các kho ứng dụng.

### Hệ quả

- Trình duyệt phải tải engine của Flutter cùng `main.dart.js` trước khi vẽ
  khung hình đầu tiên; `scripts/frontend/web-bundle.sh` cho thấy kích thước
  đó, và nó là chi phí của quyết định này ở lần mở đầu tiên.
- Output của Flutter web không hợp với việc máy tìm kiếm lập chỉ mục: HTML mà
  `app-web` trả cho một trang sản phẩm không chứa tên sản phẩm
  (`scripts/frontend/what-the-server-sends.sh`). Nếu cửa hàng cần trang sản
  phẩm công khai cho máy tìm kiếm, các trang đó làm bằng HTML dựng từ server,
  tách khỏi app, và được quyết trong một ADR riêng. Đặt hàng vẫn ở trong app.
- Thêm một nền tảng là thêm thư mục nền tảng và phần bọc API thiết bị, không
  viết lại màn hình.

Đội xem lại quyết định khi:

- Cửa hàng cần một tính năng của thiết bị mà Flutter không với tới được, kể cả
  qua phần bọc API của nền tảng.
- Đội tách thành các đội riêng theo nền tảng; lúc đó một mã chung không còn
  tiết kiệm được việc giữ đồng bộ giữa người với người.

### Ý kiến đã nhận

Product owner hỏi có nên làm app cài trên máy ngay để giữ các cửa hàng đã hỏi.
Chưa: số cửa hàng hỏi còn ít (giả định), và cùng mã này build được cho Android
và iOS khi đủ cửa hàng cần; khi đó chi phí là thư mục nền tảng và việc phát
hành lên kho ứng dụng, không phải viết lại app.

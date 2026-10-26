# 0033. Cửa hàng tự đăng ký bằng saga nhiều bước; gói và cài đặt là dữ liệu

Trạng thái: Đã chấp nhận
Ngày: đề xuất giữa Sprint 27, quyết định cuối Sprint 27
Người quyết định: trưởng nhóm, cùng product owner
Hạn góp ý: hết thứ Sáu tuần thứ hai Sprint 27

Chưa xây ở stage-4: không có code đăng ký, gói hay cài đặt cửa hàng trong repo.
Thiết kế và buổi review ở `docs/design/saas-platform-design-review.md`; chi phí
mỗi cửa hàng ở `docs/design/cost-per-shop.md`.

### Bối cảnh

`docs/team/saas-platform-requirements.md`: cửa hàng tự mở và nhận đơn đầu tiên
trong 10 phút (giả định), tự đặt tên, chọn brand, đổi gói không cần deploy, rời
đi với bản xuất dữ liệu và ngày xóa đã nói. Mở cửa hàng chạm hai chủ: dòng
`shops` trong `donhang` (Ordering) và tài khoản nhân viên trong Keycloak. App có
một `Brand` dựng sẵn, `donHangBrand` trong
`DonHang.App/lib/design/brand.dart`, có test tương phản.

### Các phương án

- Nhân viên Đơn Hàng mở cửa hàng bằng tay: không code mới, nhưng trái driver 1,
  và mỗi lần mở là một chỗ có thể sai.
- Một transaction gộp mọi bước: không làm được, vì Keycloak là chủ khác, không
  tham gia transaction của PostgreSQL.
- Saga theo bước, chạy bởi một job nền theo id đăng ký; gói và cài đặt là dữ
  liệu của cửa hàng.

### Quyết định

Chọn saga theo bước; gói và cài đặt là dữ liệu.

- Dòng `shops` ghi gói, cài đặt và trạng thái `pending`, `active`, `leaving`.
- Gói là một tập con số: phần đọc đồng thời theo ADR 0016, số tài khoản nhân
  viên, chat bật hay tắt, thời gian giữ dữ liệu (giả định). Gói là trần, không
  giữ chỗ. Đổi gói không deploy; có hiệu lực khi cache bảng ánh xạ của mỗi Pod
  hết hạn (ADR 0026).
- Tính năng theo gói là cài đặt đọc từ dữ liệu cửa hàng, sống cùng gói; không
  phải flag phát hành, thứ bị gỡ khi tính năng đã bật cho mọi khách
  (`feature-flags.md`).
- Brand: cửa hàng chọn theo tên trong các `Brand` dựng sẵn trong app, đã qua
  test tương phản. Thêm một brand là một lần phát hành app.
- Đăng ký: tạo dòng `shops` `pending` → tạo tài khoản nhân viên đầu tiên trong
  Keycloak có role `staff` và cửa hàng (token mang cửa hàng từ release 2) →
  message chào mừng qua outbox, Notifications gửi email ít nhất một lần → đặt
  `active`. Mỗi bước kiểm đã làm chưa trước khi làm.
- Bước lỗi mãi: cửa hàng ở `pending`, hiện cho nhân viên Đơn Hàng theo vai trò;
  không bao giờ mở một nửa.
- Rời đi: job xuất dữ liệu của cửa hàng; hết thời gian chờ thì xóa theo lô
  trong từng database của các service, hoặc bỏ database riêng nếu cửa hàng đã
  chuyển theo ADR 0026.

### Hệ quả

- Thêm một job saga và một bảng gói; dòng `shops` và bảng gói thuộc Ordering,
  do đội Cửa hàng phụ trách (giả định, `data-ownership.md`).
- Không màu tự do: cửa hàng chỉ chọn brand dựng sẵn; không logo.
- Rời đi phải đi qua mọi bản sao trong `data-ownership.md`.

Đội xem lại quyết định khi: cửa hàng cần màu tự do hay logo (khi đó test tương
phản phải chạy trên dữ liệu cửa hàng); số đăng ký mỗi ngày lớn tới mức job
saga thành nút cổ chai; một gói cần giữ chỗ thay vì trần.

### Ý kiến đã nhận

Product owner hỏi cửa hàng có tự chọn màu được không. Không: màu tự do có thể
không đủ tương phản, và test của app chỉ kiểm các brand dựng sẵn. Điều kiện
xem lại thứ nhất ghi trường hợp đó. Quyết định không đổi.

# 0009. Dùng Keycloak thay vì tự làm đăng nhập

Trạng thái: Đã chấp nhận
Ngày: quyết định khi làm stage-2, viết lại thành ADR trong Sprint 16
Người quyết định: trưởng nhóm
Hạn góp ý: không có (viết sau khi đã làm)

ADR này viết sau khi đã làm, theo ADR 0001. Các con số dưới đây được ước lượng
lại khi viết ADR; lúc quyết định đội chỉ so bằng lời.

### Bối cảnh

Đến stage-1, `DonHang.Api` tự làm đăng nhập: `AuthController` nhận mật khẩu,
`PasswordHasher` băm mật khẩu, `JwtTokenService` ký token. Đăng nhập là việc
mọi hệ thống đều cần, không phải điều làm Đơn Hàng khác cửa hàng khác. Những
gì sắp cần thêm (đăng nhập cho nhân viên, quên mật khẩu, khóa tài khoản khi đoán
sai nhiều lần, xác thực hai bước) đều là việc người khác đã giải.

### Các phương án

- A. Giữ code tự làm và làm tiếp các tính năng còn thiếu.
- B. Tự chạy Keycloak (mã nguồn mở), API chỉ kiểm token qua OpenID Connect.
- C. Mua một dịch vụ đăng nhập trả phí, cũng qua OpenID Connect.

### Tổng chi phí sở hữu trong 3 năm

Mọi con số là giả định của đội, không phải báo giá. Công tính bằng ngày công
của một lập trình viên; chỗ đội không chắc ghi thành khoảng. Phí ghi bằng
triệu đồng.

| Khoản | A. Code tự làm | B. Keycloak tự chạy | C. Dịch vụ trả phí |
|---|---|---|---|
| Có được (làm hoặc cài, nối vào API) | 25–40 ngày cho phần còn thiếu | 8–12 ngày | 5–8 ngày |
| Chạy (máy chủ, database) | gần như 0, chạy trong API | 1 máy nhỏ và một database, 10–20 triệu/năm | 0 |
| Phí dịch vụ | 0 | 0 | 30–90 triệu/năm, tăng theo số người dùng |
| Vận hành (nâng cấp, bản vá bảo mật, sao lưu, sự cố) | 8–15 ngày/năm | 10–20 ngày/năm | 2–4 ngày/năm |
| Thay đổi (tính năng mới, như xác thực hai bước) | 10–20 ngày mỗi tính năng | 1–3 ngày, bật trong cấu hình | 1–3 ngày, nếu gói đang mua có |
| Rời đi (chuyển tài khoản, sửa API) | không áp dụng | 5–10 ngày | 5–15 ngày, tùy vendor cho xuất gì |
| Tổng 3 năm, ngày công | 79–145 | 46–91 | 19–44 |
| Tổng 3 năm, phí | 0 | 30–60 triệu | 90–270 triệu |

Giả định chính: ba năm, dưới 50.000 tài khoản khách, một tính năng đăng nhập
mới mỗi năm, một ngày công khoảng 2 triệu đồng. Quy hết ra tiền theo giả định
đó: A khoảng 160–290 triệu, B khoảng 120–240 triệu, C khoảng 130–360 triệu.
B và C chồng lên nhau: đổi giả định số người dùng (phí của C tăng theo nó)
hoặc giá một ngày công là đủ đổi thứ tự giữa hai phương án, nên đội ghi rõ
hai giả định này.

### Quyết định

Chọn B. A đắt nhất về công và có rủi ro bảo mật mà đội không có chuyên môn để
giữ. C rẻ nhất về công nhưng phí tăng theo số khách và dữ liệu khách nằm ở máy
của vendor. B nằm giữa, và đội đã chạy PostgreSQL nên quen việc sao lưu, nâng
cấp một thành phần tự chạy. Code đăng nhập tự làm được xóa ở stage-2.

### Lock-in

API nói chuyện với Keycloak qua OpenID Connect, chuẩn mà dịch vụ đăng nhập
khác cũng dùng, nên phần lớn code không biết nó đang dùng Keycloak. Những chỗ
gắn với Keycloak:

- `DonHang.Api/Program.cs` đọc vai trò từ claim `roles` mà realm thêm vào
  token; nhà cung cấp khác đặt vai trò ở chỗ khác.
- `keycloak/donhang-realm.json` là định dạng riêng của Keycloak.
- Tài khoản khách và mật khẩu đã băm nằm trong database của Keycloak.

Đội chấp nhận mức lock-in này: đổi cả ba chỗ vẫn rẻ hơn khoản tiết kiệm.

### Kế hoạch rời đi

Ngắn, vì đăng nhập đi qua OpenID Connect:

- Dấu hiệu: Keycloak ngừng phát hành bản vá bảo mật cho dòng đang dùng, hoặc
  công vận hành vượt 20 ngày một năm hai năm liền.
- Chuyển tài khoản: xuất người dùng từ Keycloak; nếu nơi mới không nhận được
  mật khẩu đã băm, khách đặt lại mật khẩu lần đăng nhập đầu.
- Sửa API: chỗ đọc claim vai trò trong `Program.cs` và địa chỉ của nhà cung
  cấp trong cấu hình.

### Hệ quả

- Thêm một thành phần phải tự chạy (xem `docs/team/self-run-components.md`):
  trong lab Keycloak chạy ở chế độ phát triển.
- Đăng nhập không còn là code của đội; đổi màn hình đăng nhập là đổi theme của
  Keycloak.

### Ý kiến đã nhận

Không có.

# 0014. Keycloak giữ email của khách

Trạng thái: Đã chấp nhận
Ngày: đề xuất giữa Sprint 19, quyết định cuối Sprint 19
Người quyết định: trưởng nhóm
Hạn góp ý: hết thứ Sáu tuần thứ hai Sprint 19

### Bối cảnh

`docs/design/data-ownership.md` để một câu hỏi mở: email của khách nằm ở tài
khoản Keycloak và ở `customers.email`, không gì giữ hai giá trị bằng nhau, và
email đơn hàng dùng giá trị trong `customers`. Keycloak ghi tài khoản nào đã
xác minh email (`emailVerified` trong file realm); `customers` không có dấu
nào như vậy, nên chi tiết đơn có thể đi tới một địa chỉ không ai xác nhận gần
đây (phát hiện P3 của `docs/design/threat-model.md`).

Access token mà app nhận cho `donhang-api` đã mang claim `email` và
`email_verified`: client `donhang-app` có client scope `email` trong scope mặc
định. Không cần thêm mapper.

### Các phương án

- Giữ hai bản, thêm một job đồng bộ định kỳ từ Keycloak sang `customers`: hai
  nơi vẫn cùng giữ email, giữa hai lần chạy chúng vẫn lệch, và job cần một
  credential đọc được mọi tài khoản ở Keycloak.
- Keycloak là chủ; API làm mới `customers.email` từ claim `email` của access
  token mỗi khi khách đặt đơn, chỉ khi `email_verified` là `true`. Bản trong
  `customers` thành bản sao có cách giữ cho mới, không cần credential mới.
- Bỏ bản sao; Notifications hỏi Keycloak email của khách cho mỗi email gửi
  đi: không còn lệch, nhưng Notifications cần một credential đọc được mọi tài
  khoản ở Keycloak, mở rộng blast radius của một service chỉ gửi email, và mỗi
  email phụ thuộc thêm vào Keycloak.

### Quyết định

Chọn phương án thứ hai: Keycloak là chủ của email khách. Khi khách đặt đơn,
API đọc `email` và `email_verified` từ access token đã kiểm; nếu
`email_verified` là `true` và email khác `customers.email`, API cập nhật
`customers.email` trong cùng transaction với đơn. Email chưa xác minh không
được chép.

Phương án thứ ba bị từ chối vì credential của nó; phương án thứ nhất vì vẫn
giữ hai chủ và cũng cần credential đó.

### Hệ quả

- `customers.email` thành bản sao của Keycloak, mới tới lần đặt đơn gần nhất.
- `OrderMessage` giữ nguyên hình dạng: `customerEmail` vẫn lấy từ `customers`
  lúc ghi outbox, Notifications và Payments không đổi.
- Chưa làm ở stage-4: chưa có code làm mới email; câu hỏi mở trong
  `data-ownership.md` giữ nguyên, kèm dòng trỏ tới ADR này.

Đội xem lại khi email phải gửi cho khách đã lâu không đăng nhập (bản sao của
họ không được làm mới), hoặc khi một service khác cần email khách mà không có
access token của khách.

### Ý kiến đã nhận

Lập trình viên phụ trách Notifications hỏi khách đổi email rồi không đặt đơn
nữa thì sao. Email về đơn cũ (hoàn tiền) vẫn đi tới địa chỉ cũ; đây là điều
kiện xem lại thứ nhất, được ghi thay vì giải quyết trước.

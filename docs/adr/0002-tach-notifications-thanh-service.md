# 0002. Tách Notifications thành service riêng

Trạng thái: Đã chấp nhận
Ngày: quyết định trước stage-3, viết lại thành ADR trong Sprint 16
Người quyết định: trưởng nhóm
Hạn góp ý: không có (viết sau khi đã làm)

ADR này viết sau khi đã làm, theo ADR 0001; nó ghi lại lý do lúc quyết định.

### Bối cảnh

Đến stage-2, email cho khách là dòng trong bảng `notifications` của database
`donhang`. `QueuedNotifier` ghi dòng đó cùng transaction với đơn, và
`NotificationSender` chạy trong mọi bản sao của `DonHang.Api`, nhận dòng bằng
`FOR UPDATE SKIP LOCKED`. Cách này đúng cho một process. Hai điều đã đổi:

- Cổng thanh toán sắp được gọi từ một service khác (ADR 0003), và service đó
  cũng phải báo tin cho khách. Nếu email vẫn nằm trong API, Payments phải gọi
  vào API hoặc ghi vào bảng của API.
- Máy chủ email chậm hay lỗi thì job gửi chiếm tài nguyên của chính process
  đang nhận đơn. Lỗi của việc gửi email nên tách khỏi việc đặt đơn.

Chỉ chuyện số bản sao thì chưa đủ lý do: job gửi email vẫn chạy được với số
bản sao của API.

### Các phương án

- Giữ email là module trong `DonHang.Api`: không tốn gì thêm, nhưng service
  khác muốn báo tin cho khách phải đi qua API, và lỗi email vẫn nằm trong
  process nhận đơn.
- Tách `DonHang.Notifications` thành service có database riêng
  (`donhang_notifications`), nhận message qua RabbitMQ: mọi service báo tin
  cùng một cách, Notifications dừng thì đơn vẫn đặt được, message chờ trong
  queue.

### Quyết định

Tách. API ghi message vào outbox cùng transaction với đơn; message mang sẵn
email và tên khách vì Notifications không đọc bảng `customers`.

### Hệ quả

- Thêm một image, một pipeline build, một database và một dashboard phải chạy.
- Gọi qua mạng có thể lỗi; đơn và email không còn được lưu trong một
  transaction, email đến sau một lúc.
- Bảng `notifications` cũ còn lại trong `donhang`, không ai đọc (nợ N1 trong
  `docs/team/tech-debt-register.md`, ADR 0008).

### Ý kiến đã nhận

Không có.

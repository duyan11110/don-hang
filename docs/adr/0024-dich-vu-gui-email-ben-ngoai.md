# 0024. Gửi email cho khách qua Dịch vụ A, bằng SMTP

Trạng thái: Đã chấp nhận
Ngày: đề xuất đầu Sprint 23, quyết định cuối tuần đầu Sprint 23
Người quyết định: trưởng nhóm, cùng product owner
Hạn góp ý: hết thứ Sáu tuần đầu Sprint 23

Tiêu chí, trọng số, điểm và phép kiểm độ nhạy ở
`docs/team/email-service-evaluation.md`; ADR này không chép lại ma trận.

### Bối cảnh

Production chưa có cách gửi email tới khách. Notifications gửi email đơn hàng
và email báo đã hoàn tiền (YC-5 của `refund-requirements.md`) qua
`IEmailSender`, do `MailKitEmailSender` cài đặt bằng SMTP. Trong lab, SMTP đó
là Mailpit: nó bắt mọi email để xem và không gửi đi đâu.
`self-run-components.md` ghi gửi email cho khách là năng lực còn phải mua,
và cần một lần đánh giá trước khi có khách thật.

### Các phương án

- Dịch vụ A, một dịch vụ gửi email bên ngoài, nhận email qua SMTP.
- Dịch vụ B, một dịch vụ gửi email bên ngoài khác, cũng nhận qua SMTP.
- Tự chạy máy chủ gửi email.

Cả ba qua các tiêu chí loại ngay. Theo ma trận có trọng số, A và B gần như
ngang nhau và đổi chỗ khi một trọng số đổi trong khoảng đội cho là hợp lý;
tự chạy đứng cuối trong mọi trường hợp, vì giờ vận hành của đội.

### Quyết định

Chọn Dịch vụ A. Ma trận không tách được A với B, nên quyết định dựa vào hai
điều khoản hợp đồng không nằm trong các tiêu chí đã chấm:

- A báo trước 6 tháng khi đổi hoặc bỏ một phiên bản API, B báo trước 1 tháng
  (giả định, theo bản hợp đồng mẫu của hai bên).
- A cho xuất danh sách địa chỉ bị trả lại hoặc bị chặn mọi lúc, qua API; B chỉ
  cho xuất mỗi tháng một lần, qua trang quản trị.

Cả hai điều khoản quyết định cái giá của việc rời đi: đội có 6 tháng để đổi
cách gọi khi A đổi API, và mang được danh sách địa chỉ bị chặn sang dịch vụ
mới bất kỳ ngày nào, không chờ tới cuối tháng.

Tự chạy bị từ chối: nó tốn nhiều giờ vận hành nhất, và một máy chủ mới gửi
email chưa có uy tín với các nhà cung cấp hộp thư.

### Hệ quả

- Notifications giữ `IEmailSender` và `MailKitEmailSender`. Hôm nay lớp này
  nối tới Mailpit không TLS và không đăng nhập; nối tới A cần thêm hai mục cấu
  hình đó trong `SmtpSettings`, không đổi thư viện. Từ đó đổi dịch vụ gửi email
  chỉ là đổi cấu hình SMTP.
- Lab vẫn dùng Mailpit; không gì trong lab gửi email ra ngoài.
- Stage-4 không đổi code: chưa có production để nối A vào.
- A báo từng email bị trả lại bằng cách gọi ngược vào hệ thống; Notifications
  dùng nó để ngừng gửi tới địa chỉ đó. Việc này làm cùng lần nối A.

Đội xem lại quyết định khi:

- Tỉ lệ email tới hộp thư khách thấp hơn mức giả định trong
  `email-service-evaluation.md`.
- Giá của A vượt TCO giả định trong `email-service-evaluation.md`.
- A ngừng nhận email qua SMTP.

### Ý kiến đã nhận

Lập trình viên backend hỏi sao không chọn B, vì B có điểm gửi thử cao nhất.
Câu trả lời: ma trận cho thấy chênh lệch đó không đủ để quyết, vì đổi một
trọng số là thứ tự đổi; hai điều khoản ở mục Quyết định không đổi theo trọng số
nào. Quyết định không đổi.

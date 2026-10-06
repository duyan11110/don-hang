# 0003. Tách Payments thành service riêng, nối với API bằng saga

Trạng thái: Đã chấp nhận
Ngày: quyết định trước stage-3, viết lại thành ADR trong Sprint 16
Người quyết định: trưởng nhóm
Hạn góp ý: không có (viết sau khi đã làm)

ADR này viết sau khi đã làm, theo ADR 0001. Cách luồng hoàn tiền chạy từng
bước ở `docs/design/refund-design.md` (bản 2); ADR này chỉ ghi quyết định.

### Bối cảnh

Hoàn tiền phải đáp ứng `docs/team/refund-requirements.md`: nhận yêu cầu trong
2 giây kể cả khi cổng thanh toán lỗi (YC-7), không hoàn hai lần (YC-9), tự
gửi lại trong 24 giờ (YC-10). Khóa API của cổng và các dòng tiền là phần nhạy
cảm nhất của hệ thống. Ở thiết kế bản 1, mọi bản sao của `DonHang.Api` đều giữ
khóa đó và đọc ghi được bảng `payments`.

### Các phương án

- Giữ hoàn tiền trong `DonHang.Api`, như bản 1 của thiết kế ở stage-2: một
  database, một transaction cho đơn và dòng hoàn tiền. Nhưng khóa của cổng và
  dòng tiền vẫn nằm trong service lớn nhất, ai deploy API cũng chạm tới chúng.
- `DonHang.Payments` là service riêng với database `donhang_payments`, nối với
  API bằng saga qua message (outbox, inbox, RabbitMQ): khóa và dòng tiền chỉ ở
  một service, được triển khai và cấp quyền riêng.
- `DonHang.Payments` riêng, giữ một transaction chung bằng two-phase commit
  qua hai database, RabbitMQ và cổng.

### Quyết định

Chọn service riêng nối bằng saga. Loại two-phase commit vì RabbitMQ và cổng
thanh toán không tham gia được một transaction như thế: API HTTP của cổng
không có bước chuẩn bị, RabbitMQ không tham gia transaction của PostgreSQL.
Loại phương án giữ trong API vì khóa của cổng và dòng tiền không nằm trong
một service của riêng chúng.

### Hệ quả

- Đơn và yêu cầu hoàn tiền chỉ khớp nhau sau một lúc: trong khoảng đó đơn ở
  `refunding` còn dòng bên Payments đang `pending`.
- Thêm một service phải chạy, với database, image và dashboard của nó.
- Mỗi bước phải lặp lại được an toàn, vì message có thể đến hai lần.
- Lỗi phải được bù bằng một bước ngược (đơn quay về `paid`), không rollback
  được.
- Bảng `payments` cũ còn lại trong `donhang` (nợ N2 trong
  `docs/team/tech-debt-register.md`, ADR 0008).

### Ý kiến đã nhận

Không có.

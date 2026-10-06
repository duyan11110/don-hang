# Quyết định kiến trúc của Đơn Hàng

Mỗi file trong thư mục này là một ADR (architecture decision record): một
quyết định khó đảo ngược, bối cảnh dẫn tới nó, quyết định và hệ quả. ADR nằm
cạnh code nên được review và lưu phiên bản cùng code mà nó giải thích. Cách
làm này được chọn trong ADR 0001.

### Danh sách

| Số | Quyết định | Trạng thái |
|---|---|---|
| 0001 | [Ghi quyết định kiến trúc bằng ADR](0001-ghi-quyet-dinh-bang-adr.md) | Đã chấp nhận |
| 0002 | [Tách Notifications thành service riêng](0002-tach-notifications-thanh-service.md) | Đã chấp nhận |
| 0003 | [Tách Payments thành service riêng, nối bằng saga](0003-tach-payments-thanh-service.md) | Đã chấp nhận |
| 0004 | [Giữ `Order` lưu theo trạng thái, không event sourcing](0004-giu-order-luu-theo-trang-thai.md) | Đã chấp nhận |
| 0005 | [Mỗi môi trường một bản manifest đầy đủ](0005-moi-moi-truong-mot-ban-manifest.md) | Bị thay thế bởi 0007 |
| 0006 | [Secret trong repo cấu hình chỉ ở dạng đã mã hóa](0006-ma-hoa-secret-trong-repo-cau-hinh.md) | Đã chấp nhận |
| 0007 | [Overlay Kustomize cho repo cấu hình](0007-overlay-kustomize-cho-repo-cau-hinh.md) | Đã chấp nhận |
| 0008 | [Xóa hai bảng cũ trong database `donhang`](0008-xoa-bang-cu-trong-donhang.md) | Đã chấp nhận |
| 0009 | [Dùng Keycloak thay vì tự làm đăng nhập](0009-dung-keycloak-thay-vi-tu-lam-dang-nhap.md) | Đã chấp nhận |
| 0010 | [Cổng thanh toán bên ngoài cho hoàn tiền](0010-cong-thanh-toan-ben-ngoai.md) | Đã chấp nhận |

### Khi nào viết một ADR

Khi quyết định tốn kém nếu phải đảo ngược, hoặc khi về sau người ta sẽ hỏi vì
sao lại làm như vậy. Một lựa chọn dễ đổi lại (tên một biến, thứ tự hai bước
trong script) không cần ADR.

### Quy trình

1. Chép `template.md` thành file mới với số kế tiếp, trạng thái `Đề xuất`.
2. Mở pull request chỉ chứa ADR đó. Mô tả của pull request ghi hạn góp ý
   (thường là năm ngày làm việc) và gắn những người quyết định này ảnh hưởng
   tới.
3. Mọi ý kiến được trả lời trong pull request. Ý kiến làm quyết định thay đổi
   được ghi vào mục "Ý kiến đã nhận" của ADR, kể cả ý kiến phản đối.
4. Hết hạn góp ý, trưởng nhóm quyết định. Mục tiêu là nghe hết các phản đối
   trước khi quyết, không phải để mọi người cùng đồng ý.
5. Trước khi merge, trạng thái thành `Đã chấp nhận` hoặc `Bị từ chối`. ADR bị
   từ chối vẫn được merge và giữ lại, để cùng ý tưởng đó không được đề xuất lại
   mà không có lý do mới.

ADR đã chấp nhận không được viết lại. Khi quyết định đổi, một ADR mới ghi
quyết định mới; ADR cũ chỉ được sửa trạng thái thành `Bị thay thế bởi NNNN`
kèm đường dẫn. Đội không dùng file riêng cho bản đề xuất (có đội gọi đó là
RFC): ADR ở trạng thái `Đề xuất` đóng cả hai vai.

Tài liệu thiết kế (`docs/design/`) thì khác: nó mô tả cách làm một việc và
được sửa theo kế hoạch. ADR trỏ tới tài liệu thiết kế thay vì chép lại nó.

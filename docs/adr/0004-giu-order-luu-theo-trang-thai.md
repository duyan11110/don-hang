# 0004. Giữ `Order` lưu theo trạng thái, không event sourcing

Trạng thái: Đã chấp nhận
Ngày: quyết định khi làm lịch sử trạng thái của đơn, viết lại thành ADR trong
Sprint 16
Người quyết định: trưởng nhóm
Hạn góp ý: không có (viết sau khi đã làm)

ADR này viết sau khi đã làm, theo ADR 0001. Ba phương án và cách so chúng ở
`docs/design/order-history-design.md`; ADR này chỉ ghi quyết định.

### Bối cảnh

Khách và nhân viên muốn xem một đơn đã qua những trạng thái nào. Event
sourcing cho `Order` trả lời được câu hỏi đó và nhiều câu khác, nên có người
đề nghị đổi cả cách lưu đơn.

### Các phương án

- Event sourcing cho `Order`.
- Giữ `Order` lưu theo trạng thái, thêm read model `order_status_history` cập
  nhật từ domain event trong cùng transaction.
- Đọc bảng `outbox_messages`.

### Quyết định

Không event-source `Order`; dùng read model. Nhu cầu chỉ là một danh sách cho
từng đơn, trong khi event sourcing đổi cách mọi use case, truy vấn và test
nạp và lưu đơn.

### Hệ quả

- Đơn có trước stage-3 chỉ có một dòng `placed` trong lịch sử.
- Mỗi lần đổi trạng thái thêm một lệnh INSERT.

Xem lại quyết định này khi có yêu cầu cho biết cả đơn trông thế nào ở một
thời điểm bất kỳ trong quá khứ, khi nhiều read model mới cùng cần các thay đổi
của đơn, hoặc khi kiểm toán đòi chứng minh lịch sử chưa từng bị sửa.

### Ý kiến đã nhận

Không có.

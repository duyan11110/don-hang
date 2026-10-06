# 0008. Xóa hai bảng cũ trong database `donhang`

Trạng thái: Đã chấp nhận
Ngày: đề xuất đầu Sprint 17, quyết định cuối tuần đầu Sprint 17
Người quyết định: trưởng nhóm
Hạn góp ý: hết thứ Sáu tuần đầu Sprint 17

### Bối cảnh

Sau khi Notifications và Payments có database riêng (ADR 0002, 0003), bảng
`notifications` và `payments` vẫn còn trong database `donhang`. Không code nào
đọc hay ghi chúng. Chúng là nợ N1 và N2 trong
`docs/team/tech-debt-register.md`: người mới đọc schema tưởng API còn gửi
email và giữ dòng tiền, và mỗi lần sửa migration của `donhang` lại phải hỏi
hai bảng đó còn dùng không.

### Các phương án

- Giữ hai bảng: không tốn gì, tiếp tục gây hiểu nhầm.
- Xóa ngay trong migration kế tiếp: hết nợ nhanh nhất, nhưng mất dữ liệu cũ
  nếu ai đó còn cần.
- Xuất dữ liệu của hai bảng ra file dump, giữ file đó, rồi xóa bảng bằng một
  migration.

### Quyết định

Xuất rồi xóa, theo thứ tự:

1. Dump hai bảng bằng `pg_dump -Fc --table`, lưu cùng các bản sao lưu khác.
2. Migration xóa `notifications` trước, cùng pull request bỏ bảng đó khỏi
   lệnh `TRUNCATE` của `PostgresFixture`.
3. Migration xóa `payments` sau khi kế toán xác nhận đã đối chiếu xong với
   `donhang_payments`, cũng sửa `PostgresFixture` như bước 2.

Ở tag stage-3 hai bảng vẫn còn; các bước trên làm trong sprint sau.

### Hệ quả

- Schema của `donhang` chỉ còn bảng API thật sự dùng.
- Dữ liệu cũ chỉ còn trong file dump; đọc lại cần khôi phục vào một database
  tạm.
- Không xóa cùng lúc nên có một khoảng chỉ còn bảng `payments` cũ.

### Ý kiến đã nhận

- Kế toán phản đối việc xóa `payments` ngay: các khoản thanh toán cũ là thứ họ
  đối soát cuối quý, và họ chưa kiểm bản chép sang `donhang_payments`. Quyết
  định đổi vì phản đối này: bảng `payments` chỉ bị xóa sau khi kế toán xác
  nhận (bước 3), không cùng lúc với `notifications` như bản đề xuất ban đầu.
- Tester hỏi test tích hợp có dựa vào hai bảng không. Không test nào đọc
  chúng, nhưng `PostgresFixture` xóa sạch dữ liệu của cả hai giữa các test
  (lệnh `TRUNCATE`). Mỗi migration xóa bảng vì thế sửa lệnh đó trong cùng
  pull request; điều này được thêm vào bước 2 và 3.

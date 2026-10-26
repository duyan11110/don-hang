# Thiết kế: nhật ký kiểm toán

Trạng thái: kế hoạch, chưa dựng ở stage-4. Trả lời phát hiện P4 của
`threat-model.md` và yêu cầu ghi lại mỗi lần xin ký hóa đơn của ADR 0015.

### Vì sao những gì đang có chưa đủ

- `requested_by` và `requested_at` của dòng hoàn tiền (YC-8) nằm trong bảng
  `payments` của `donhang_payments`. Payments sửa được chúng, và bất kỳ ai có
  user chung `donhang` cũng vậy; sửa không để lại dấu vết. `requested_by` lại
  là email lấy từ message, không phải `sub` của người gọi.
- `order_status_history` là read model mà API ghi cùng transaction với đơn. Nó
  ghi đơn đổi sang trạng thái nào, không ghi ai đổi, và API sửa được nó.
- Log trong Loki dùng để tìm lỗi: service nào cũng ghi được bất kỳ dòng nào ra
  output của mình, nên log không chứng minh được ai đã làm gì.

### Hành động được kiểm toán

| Hành động | Ai ghi entry |
|---|---|
| Giao đơn (`PATCH /api/v1/orders/{id}/ship`) | API |
| Yêu cầu hoàn tiền (`POST /api/v1/orders/{id}/refund`) | API |
| Đổi giá sản phẩm (`PATCH /api/v1/products/{id}`) | API |
| Cấp hay bỏ một role ở Keycloak | Keycloak; cách lấy entry từ Keycloak quyết khi dựng |
| Xin ký một hóa đơn | Payments |

### Trường của mỗi entry

| Trường | Nội dung |
|---|---|
| `actor` | `sub` của người gọi, lấy từ token đã kiểm; job nền ghi tên service |
| `action` | Tên hành động, ví dụ `order.ship` |
| `resource` | Đối tượng bị tác động, ví dụ `order/42` |
| `at` | Thời điểm, theo giờ của service ghi |
| `outcome` | `allowed`, `denied` hoặc `failed`, kèm mã lỗi nếu có |
| `prev_hash` | Hash của entry ngay trước trong cùng chuỗi |
| `hash` | Hash của entry này, tính cả `prev_hash` |

Không entry nào chứa token, mật khẩu, khóa hay secret, kể cả khi hành động
thất bại vì chúng.

### Chuỗi hash

Mỗi entry mang hash của entry trước, nên sửa hay xóa một entry làm sai mọi
hash sau nó. Một job kiểm định kỳ tính lại chuỗi và báo chỗ đầu tiên bị sai.
Nhờ vậy nhật ký là tamper-evident: nó không ngăn được việc sửa, nhưng mọi lần
sửa đều lộ ra.

### Nơi lưu

Entry được gửi tới một kho tách khỏi database của các service, nơi service chỉ
được ghi thêm: không sửa, không xóa. User chung `donhang` và role của service
không có quyền gì trên kho đó. Đọc kho chỉ dành cho người kiểm toán và trưởng
nhóm.

### Thời hạn lưu

Thỏa thuận với nghiệp vụ, kế toán và pháp chế; giả định 5 năm cho tới khi họ
trả lời. Sản phẩm dùng làm kho và nơi chạy nó chưa chọn.

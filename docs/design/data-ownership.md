# Thiết kế: chủ của từng loại dữ liệu

Trạng thái: mô tả hệ thống ở stage-4. Mỗi loại dữ liệu có đúng một chủ: module
hay service ghi nó, và giá trị của chủ là giá trị đúng khi các bản sao lệch
nhau. Mọi nơi khác chỉ giữ bản sao, và mỗi bản sao cần một cách giữ cho mới
hoặc một lý do nói rõ vì sao không. Thao tác nào được trả lời bằng bản sao
ở `consistency-per-operation.md`.

### Bảng chủ dữ liệu

| Dữ liệu | Chủ (module/service, database) | Ai giữ bản sao | Bản sao cập nhật thế nào, hoặc vì sao không | Khi lệch thì tin ai |
|---|---|---|---|---|
| Sản phẩm, giá (`products`) | Catalog, `donhang` | Redis (`product:{id}`) | Xóa sau khi đổi giá; dù lệnh xóa bị lỡ, bản sao sống tối đa 5 phút (TTL). `order_items.unit_price_vnd` không phải bản sao: đó là giá khách đã trả, một dữ kiện của đơn, cố ý không đổi theo giá mới | `products` |
| Đơn (`orders`, `order_items`), khách (`customers`) | Ordering, `donhang` | `order_status_history` (read model); Payments chỉ giữ `order_id` | `RecordOrderStatusHistory` ghi read model cùng transaction với đơn; `order_id` bên Payments là một con số, không có khóa ngoại | `orders` |
| Thanh toán, hoàn tiền (`payments`) | Payments, `donhang_payments` | Bảng `payments` cũ trong `donhang` | Không ai cập nhật: bản chép lúc tách service (ADR 0003); kế toán đối soát với `donhang_payments`, nên bảng cũ chỉ bị xóa sau khi kế toán xác nhận (ADR 0008) | `donhang_payments` |
| Email cần gửi (`notifications`) | Notifications, `donhang_notifications` | Không còn: bảng cũ trong `donhang` đã xóa ở stage-4 (ADR 0008, bước 2) | | `donhang_notifications` |
| Tài khoản đăng nhập (email, mật khẩu, role) | Keycloak, database `keycloak` | `customers.identity_subject` trỏ tới tài khoản (`sub`) | Chỉ là khóa trỏ tới, không chép dữ liệu tài khoản | Keycloak |
| Email và tên của khách | Ordering, `customers` | Mỗi message `order.*` (`customerEmail`, `customerName`); dòng `notifications`; `requested_by` của dòng hoàn tiền | Chép lúc message được ghi vào outbox; cố ý không cập nhật về sau: email gửi theo đúng message đã nhận | `customers` |
| Lựa chọn kênh của khách (notification preferences): SMS, push ngoài email | Notifications, `donhang_notifications` (chưa có ở stage-4, ADR 0027) | Không ai | | `donhang_notifications` |

### Bản sao ngoài các service

Bản dump và base backup trong volume `backups`, WAL trong `wal-archive`, và
`db-replica` (profile `replica`) giữ bản sao của mọi database trên server.
Chúng không bao giờ là chủ: khi lệch, tin database đang chạy, trừ khi đang
khôi phục.

### Khi hai nơi cùng muốn sửa một dữ liệu

Không cho cả hai cùng ghi. Dữ liệu được giao cho một chủ; nơi còn lại hỏi chủ
qua một lời gọi hay một message. Ví dụ ở stage-3: Payments không đổi trạng
thái đơn, nó gửi `payment.refunded` và API, chủ của đơn, tự đổi.

### Câu hỏi mở

Email của khách nằm ở hai nơi: tài khoản Keycloak và cột `customers.email`.
Không gì giữ hai giá trị bằng nhau. Email đơn hàng dùng giá trị trong
`customers`, nên khách đổi email ở Keycloak vẫn nhận email ở địa chỉ cũ, và
Keycloak ghi tài khoản nào đã xác minh email (`emailVerified`) còn
`customers` thì không. Chưa quyết ai là chủ.

- Người phụ trách: trưởng nhóm, cùng lập trình viên backend.
- Không ghi vào sổ nợ: đây là một quyết định chưa có, chưa phải một món nợ.
- Đã quyết ở ADR 0014 (Keycloak giữ email khách), chưa làm ở stage-4.

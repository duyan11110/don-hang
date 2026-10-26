# Thiết kế: threat model của Đơn Hàng

Trạng thái: viết ở stage-4 cho luồng dữ liệu của stage-3 (sơ đồ "Data flow"
trong `STAGE.md`): Compose trong lab và cluster staging. Mỗi ranh giới tin cậy
được hỏi đủ sáu loại mối đe dọa của STRIDE: giả danh (S), sửa dữ liệu (T),
chối bỏ (R), lộ thông tin (I), từ chối dịch vụ (D), leo thang quyền (E). Mỗi
mối đe dọa có biện pháp đang có, hoặc một phát hiện kèm quyết định: sửa,
chấp nhận có lý do, hay hoãn theo một kế hoạch nêu tên. Chỉ ghi những dòng có
điều để nói.

### Trình duyệt → Caddy / Gateway

| STRIDE | Mối đe dọa | Biện pháp hoặc phát hiện |
|---|---|---|
| S | Gọi API bằng token giả hay token của người khác | API và Payments tự kiểm chữ ký, issuer, audience, hạn của mọi token (`AddJwtBearer`); Caddy và Gateway không kiểm token |
| T, I | Đọc hay sửa request trên đường truyền | Staging: HTTPS ở Gateway (chứng chỉ của lab CA). Compose: HTTP thường, chỉ trên máy dev |
| D | Một khách hay một trang gửi quá nhiều request | Giới hạn `orders` (theo `sub`) và `catalog-reads` (số đọc đồng thời) trong `Program.cs`, giữ nguyên |
| E | Khách gọi việc của nhân viên | Policy `StaffOnly` đọc role `staff` trong token; `OrderOwner` chỉ cho xem đơn của chính mình |

### Gateway → API, Payments

| STRIDE | Mối đe dọa | Biện pháp hoặc phát hiện |
|---|---|---|
| S | Pod khác gọi thẳng API, bỏ qua Gateway | NetworkPolicy `from-the-gateway`: chỉ Pod của Traefik tới được api và Payments; hai service vẫn kiểm mọi token |
| T, I | Đọc hay sửa request trong cluster | P5 |

### Service → PostgreSQL

| STRIDE | Mối đe dọa | Biện pháp hoặc phát hiện |
|---|---|---|
| I, E | Một service bị chiếm đọc database của service khác | P1 |
| T, R | Service sửa lại dòng ghi ai đã yêu cầu gì | P4 |
| S | Pod lạ kết nối database | NetworkPolicy `db`: chỉ các service, migration và job backup |

### Service → RabbitMQ

| STRIDE | Mối đe dọa | Biện pháp hoặc phát hiện |
|---|---|---|
| S, T | Một service bị chiếm publish message giả danh service khác, ví dụ `payment.refunded` | P2 |
| D | Message hỏng làm consumer quay vòng mãi | Quorum queue có `x-delivery-limit`, dead-letter queue mỗi service |

### Payments → cổng thanh toán

| STRIDE | Mối đe dọa | Biện pháp hoặc phát hiện |
|---|---|---|
| I | Lộ khóa API của cổng | Khóa chỉ trong cấu hình của Payments; trên staging là SealedSecret (ADR 0006) |
| T | Gửi lại sau lỗi mạng hoàn tiền hai lần | Idempotency key `refund-<id>` (YC-9) |
| D | Cổng chậm làm nghẽn Payments | Timeout, thử lại có backoff, circuit breaker |

### Notifications → SMTP

| STRIDE | Mối đe dọa | Biện pháp hoặc phát hiện |
|---|---|---|
| I | Email chi tiết đơn tới địa chỉ không còn của khách | P3 |
| T, I | Đọc email trên đường truyền | Lab: Mailpit, không TLS, không có email thật. Máy chủ email thật cần TLS, quyết khi chọn dịch vụ email |

### API, Payments → Keycloak

| STRIDE | Mối đe dọa | Biện pháp hoặc phát hiện |
|---|---|---|
| S | Ai đó trả khóa công khai giả khi service tải khóa | Service tải khóa từ Keycloak trong mạng nội bộ; NetworkPolicy `keycloak` và egress policy giới hạn đường đi. Chấp nhận cho lab (`RequireHttpsMetadata = false`) |
| I | Đọc bảng tài khoản của Keycloak | Compose: database `keycloak` nằm trên cùng server, P1. Staging: Keycloak chạy `start-dev` với dữ liệu của riêng nó |

### Phát hiện và quyết định

| Số | Phát hiện | Quyết định | Người phụ trách |
|---|---|---|---|
| P1 | API, Notifications và Payments cùng vào PostgreSQL bằng `donhang`, superuser do image `db` tạo từ `POSTGRES_USER`; với thông tin đó mở được mọi database trên server, và trong Compose cả database `keycloak` (Keycloak cũng dùng `donhang`) | Hoãn: role riêng cho mỗi service, chỉ có quyền trên database của nó, làm ở release 3 của `multi-shop-data-rollout.md` | Lập trình viên backend |
| P2 | Ba service vào RabbitMQ bằng `donhang`, user mặc định của broker, được configure, write, read trên mọi thứ của vhost `/` | Hoãn: user riêng cho mỗi service, cùng release 3 | Lập trình viên backend |
| P3 | `customers.email` không có dấu đã xác minh; email đơn hàng gửi tới địa chỉ đó | Sửa theo ADR 0014 (Keycloak giữ email khách) | Trưởng nhóm |
| P4 | `requested_by` của dòng hoàn tiền và `order_status_history` do chính service ghi, sửa được bằng service đó và bằng user chung `donhang`; sửa không để lại dấu vết | Hoãn: nhật ký kiểm toán theo `audit-log.md` | Lập trình viên backend |
| P5 | Gateway gọi các Pod api và Payments bằng HTTP thường: NetworkPolicy quyết ai được kết nối, nhưng dữ liệu đi qua mạng giữa các node không mã hóa, và api chỉ biết bên gọi qua địa chỉ của nó | Chấp nhận: một cluster, một đội, NetworkPolicy đã giới hạn bên gọi. Mã hóa và xác minh bên gọi trong cluster xem lại ở module Kubernetes nhiều cluster | Lập trình viên phụ trách nền tảng |
| P6 | Hóa đơn ký số (kế hoạch) cần một khóa riêng mà chỉ Đơn Hàng ký được | Quyết ở ADR 0015 (khóa trong HSM) | Trưởng nhóm |

### Khi nào xem lại

Mỗi khi luồng dữ liệu đổi: thêm service, thêm ranh giới, thêm bên ngoài.
Lần đổi đã biết là đưa `shop_id` vào (ADR 0013): nó thêm mối đe dọa một cửa
hàng đọc dữ liệu của cửa hàng khác, được trả lời bằng row-level security đứng
sau bộ lọc cửa hàng trong code. P1 và P2 được sửa trong cùng release 3, vì
release đó vốn đã chuyển service sang role không có `BYPASSRLS`.

# Thiết kế: luồng hoàn tiền

Trạng thái: đã làm, bản 2. Bản 1 (Sprint 15) giữ mọi thứ trong DonHang.Api;
bản này tách thanh toán thành service `DonHang.Payments` và viết lại các bước
cho phù hợp. Thiết kế trả lời `docs/team/refund-requirements.md` (YC-1 đến
YC-10). Rủi ro và việc theo dõi chúng ở `docs/team/risk-register-example.md`.

## Tóm tắt

Khách gửi yêu cầu hoàn tiền; DonHang.Api chỉ đổi trạng thái đơn và ghi một
message vào outbox, rồi trả lời ngay. `DonHang.Payments` nhận message, ghi
yêu cầu vào cơ sở dữ liệu của mình, rồi một job nền gửi yêu cầu sang cổng
thanh toán, thử lại với backoff khi lỗi, mỗi lần kèm cùng một idempotency
key. Kết quả quay lại DonHang.Api bằng message. Lý do chính vẫn như bản 1:
YC-7 đòi nhận yêu cầu cả khi cổng thanh toán đang lỗi.

## Vì sao tách DonHang.Payments

Khóa API của cổng thanh toán và các dòng tiền của đơn là thứ nhạy cảm nhất
của hệ thống. Ở bản 1, mọi bản sao của DonHang.Api đều giữ khóa đó và đọc ghi
được bảng `payments`. Tách ra, khóa chỉ nằm trong cấu hình của một service,
bảng `payments` chỉ nằm trong cơ sở dữ liệu `donhang_payments` của service đó,
và service này được triển khai, cấp quyền truy cập và kiểm toán riêng. DonHang.Api
không còn đọc hay ghi dòng tiền nào; nó chỉ biết kết quả qua message.

## Thiết kế

1. Khách gọi `POST /api/v1/orders/{id}/refund`. DonHang.Api kiểm tra đơn thuộc
   về người gọi (YC-2) và đang `paid` (YC-1), chuyển đơn sang `refunding`, ghi
   một dòng `order.refund-requested` vào `outbox_messages` trong cùng
   transaction, rồi trả `202 Accepted`. Request không chờ ai khác (YC-7).
2. Khi đơn đang `refunding`, yêu cầu hoàn tiền thứ hai, hủy đơn và giao hàng
   đều bị từ chối với `409` (YC-4).
3. `DonHang.Payments` nhận `order.refund-requested` từ RabbitMQ, ghi một dòng
   hoàn tiền `pending` vào bảng `payments` của mình với người yêu cầu và thời
   điểm (YC-8), số tiền bằng khoản đã thanh toán của đơn (YC-3). Id của message
   được ghi vào `inbox_messages` trong cùng transaction, nên message lặp lại
   không tạo dòng thứ hai; một unique index trên `order_id` cho các dòng
   `refund` cũng chặn điều đó.
4. Một job nền trong `DonHang.Payments`, cùng cách với `NotificationSender`: hai
   giây một lần, nhận các dòng đến hạn bằng `FOR UPDATE SKIP LOCKED`, gọi API
   hoàn tiền của cổng thanh toán cho từng dòng, với idempotency key
   `refund-<id của dòng>`. Gửi lại sau lỗi mạng dùng đúng key đó, nên cổng
   không hoàn tiền lần hai (YC-9).
5. Cổng lỗi hoặc không trả lời: thử lại sau 1 phút, rồi 2, 4, 8 phút, tối đa 1
   giờ giữa hai lần, trong 24 giờ kể từ `requested_at` (YC-10). Hết 24 giờ, hoặc
   cổng từ chối hẳn, dòng thành `failed` kèm lý do, hiện trong
   `GET /api/v1/refunds?status=failed` cho nhân viên (YC-6), và một message
   `payment.refund-failed` được ghi vào outbox của Payments trong cùng
   transaction.
6. Cổng xác nhận: dòng thành `refunded` với `paid_at`, và một message
   `payment.refunded` được ghi vào outbox, trong cùng một transaction.
7. DonHang.Api nhận `payment.refunded`: đơn chuyển sang `cancelled` và một dòng
   `order.refunded` được ghi vào outbox, trong cùng transaction. Notifications
   gửi email báo đã hoàn tiền (YC-5).
8. DonHang.Api nhận `payment.refund-failed`: đơn quay về `paid` (hành động bù:
   đơn lại giao được) và một dòng `order.refund-failed` được ghi vào outbox;
   Notifications báo cho khách. Dòng `failed` bên Payments giữ nguyên làm lịch
   sử, không bị xóa.

Không service nào điều khiển cả chuỗi: mỗi service phản ứng với message của
service khác (choreography). Muốn theo một yêu cầu hoàn tiền, đọc binding và
consumer của ba service.

## Phương án bị loại: một transaction phân tán (two-phase commit)

Bản 1 ghi dòng hoàn tiền, trạng thái đơn và email trong một transaction, vì
mọi thứ cùng nằm trong một cơ sở dữ liệu. Sau khi tách, giữ được điều đó cần
two-phase commit qua `donhang`, `donhang_payments`, RabbitMQ và cổng thanh
toán. Không làm được: RabbitMQ không tham gia được transaction của PostgreSQL,
API HTTP của cổng không có bước prepare, và chính PostgreSQL của Đơn Hàng tắt
`PREPARE TRANSACTION` (`max_prepared_transactions` là 0). Kể cả làm được, một
coordinator dừng giữa chừng sẽ để các dòng bị khóa cho tới khi nó quay lại.
Vì vậy mỗi bước là một transaction cục bộ, nối với nhau bằng outbox và inbox.

## Phương án bị loại: gọi cổng thanh toán ngay trong request của khách

Đơn giản hơn: không cột trạng thái, không job. Nhưng khi cổng lỗi hoặc chậm,
khách chờ rồi nhận lỗi, và yêu cầu không được ghi lại. Điều đó trái YC-7, nên
phương án này bị loại, như ở bản 1.

## Không làm trong thiết kế này

- Không có bộ điều phối (orchestrator) riêng cho chuỗi hoàn tiền: ba bước,
  hai nhánh thất bại, choreography đủ dùng.
- Không nhận thông báo kết quả do cổng gọi ngược vào hệ thống: cổng trả kết
  quả ngay trong câu trả lời của lời gọi hoàn tiền.
- Không hoàn một phần, không đơn `shipped` (ngoài phạm vi của yêu cầu).
- Không làm luồng thanh toán (charge) trong `DonHang.Payments`: 8 khoản thanh
  toán có sẵn được chép sang `donhang_payments`; bảng `payments` cũ trong
  `donhang` vẫn còn nhưng không ai đọc.

## Rủi ro và câu hỏi mở

- Nếu cổng không nhận idempotency key, bước 4 phải đổi thành hỏi trạng thái
  hoàn tiền trước mỗi lần gửi lại (R2 trong sổ rủi ro).
- Nếu cổng chỉ báo kết quả sau, bằng cách gọi ngược vào hệ thống, bước 6 phải
  đổi (R1).
- Câu hỏi mở của bản 1 đã đóng: từ bản này `Order.Cancel()` từ chối đơn
  `paid`, nên mọi đơn đã thanh toán rời đi qua luồng hoàn tiền.

## Lịch sử

- Bản 1, Sprint 15 planning: bản đầu, mọi thứ trong DonHang.Api.
- Bản 2: tách `DonHang.Payments`, loại two-phase commit, các bước nối bằng
  RabbitMQ qua outbox và inbox; chặn hủy đơn `paid`.

Khi kế hoạch đổi, file này được sửa trong cùng pull request với code, không để
nó mô tả ý tưởng đầu tiên.

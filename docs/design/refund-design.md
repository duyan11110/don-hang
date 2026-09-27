# Thiết kế: luồng hoàn tiền

Trạng thái: đề xuất, chưa làm; đội Đơn Hàng review như một pull request trước
khi viết code. Thiết kế này trả lời `docs/team/refund-requirements.md` (YC-1
đến YC-10). Rủi ro và việc theo dõi chúng ở `docs/team/risk-register-example.md`.

## Tóm tắt

Khách gửi yêu cầu hoàn tiền; API chỉ ghi yêu cầu vào cơ sở dữ liệu và trả lời
ngay. Một job nền gửi yêu cầu sang cổng thanh toán, thử lại với backoff khi lỗi,
và mỗi lần gửi kèm cùng một idempotency key. Lý do chính: YC-7 đòi nhận yêu cầu
cả khi cổng thanh toán đang lỗi.

## Thiết kế đề xuất

1. Khách gọi `POST /api/v1/orders/{id}/refund`. API kiểm tra đơn thuộc về người
   gọi (chính sách `OrderOwner` sẵn có, YC-2) và đang `paid` (YC-1), ghi một
   dòng hoàn tiền `pending` vào bảng `payments` với người yêu cầu và thời điểm
   (YC-8), rồi trả `202 Accepted`. Request không gọi cổng thanh toán (YC-7).
2. Bảng `payments` có sẵn thêm các cột: `kind` (`charge` hoặc `refund`),
   `status`, `requested_by`, `requested_at`, `attempts`, `next_attempt_at`,
   `failure_reason`; `paid_at` được để trống cho tới khi hoàn tiền xong. Một
   unique index trên `order_id` cho các dòng `refund` chặn yêu cầu thứ hai cho
   cùng đơn (YC-4). Số tiền là `amount_vnd` của khoản đã thanh toán (YC-3).
3. Một job nền trong API, cùng cách với `NotificationSender`: hai giây một lần,
   nhận các dòng đến hạn bằng `FOR UPDATE SKIP LOCKED`, gọi API hoàn tiền của
   cổng thanh toán cho từng dòng.
4. Mỗi lần gọi gửi idempotency key `refund-<id của dòng>`. Gửi lại sau lỗi mạng
   dùng đúng key đó, nên cổng không hoàn tiền lần hai (YC-9).
5. Cổng lỗi hoặc không trả lời: thử lại sau 1 phút, rồi 2, 4, 8 phút, tối đa 1
   giờ giữa hai lần, trong 24 giờ kể từ `requested_at` (YC-10). Hết 24 giờ, hoặc
   cổng từ chối hẳn, dòng thành `failed` kèm lý do và hiện trong
   `GET /api/v1/refunds?status=failed` cho nhân viên (chính sách `StaffOnly`,
   YC-6).
6. Cổng xác nhận: trong cùng một transaction, dòng thành `refunded` với
   `paid_at`, đơn chuyển sang `cancelled`, và một dòng `notifications`
   `pending` được thêm; email đi theo đường của mọi thông báo khác (YC-5).

## Phương án bị loại: gọi cổng thanh toán ngay trong request của khách

Đơn giản hơn: không cột trạng thái, không job. Nhưng khi cổng lỗi hoặc chậm,
khách chờ rồi nhận lỗi, và yêu cầu không được ghi lại. Điều đó trái YC-7, nên
phương án này bị loại.

## Không làm trong thiết kế này

- Không thêm bảng: tên bảng của hệ thống cố định, và một khoản hoàn tiền là
  một dòng tiền của đơn, cùng loại với khoản thanh toán.
- Không tách service riêng cho thanh toán, không nhận thông báo kết quả do cổng
  gọi ngược vào hệ thống: thiết kế giả định cổng trả kết quả ngay trong câu trả
  lời của lời gọi hoàn tiền.
- Không hoàn một phần, không đơn `shipped` (ngoài phạm vi của yêu cầu).

## Rủi ro và câu hỏi mở

- Nếu cổng không nhận idempotency key, bước 4 phải đổi thành hỏi trạng thái
  hoàn tiền trước mỗi lần gửi lại (R2 trong sổ rủi ro).
- Nếu cổng chỉ báo kết quả sau, bằng cách gọi ngược vào hệ thống, bước 6 phải
  đổi; câu trả lời có sau tuần thử môi trường test (R1).
- Hôm nay `PATCH /api/v1/orders/{id}/cancel` vẫn hủy được đơn `paid`
  (`Order.Cancel()` chỉ chặn `cancelled` và `shipped`), dù ứng dụng không có
  nút hủy. Product owner quyết định có chặn trường hợp đó trong đợt này không,
  để mọi đơn đã thanh toán đi qua luồng hoàn tiền.

## Lịch sử

- Bản 1, Sprint 15 planning: bản đầu, chờ review.

Khi kế hoạch đổi, file này được sửa trong cùng pull request với code, không để
nó mô tả ý tưởng đầu tiên.

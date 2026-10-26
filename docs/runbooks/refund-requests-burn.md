# Runbook: RefundRequestsFastBurn

Alert: `RefundRequestsFastBurn` (`severity: page`), rule trong
`deploy/gitops/config-repo/platform/monitoring/rules/slo.rules.yml`. SLI S4
của `docs/design/slo.md`: yêu cầu hoàn tiền trả lời trong bucket 2,048 giây
(YC-7).

### Ý nghĩa với khách

Hơn 13,44% yêu cầu hoàn tiền (`POST` `api/v1/orders/{id:int}/refund`) trong cả
1 giờ lẫn 5 phút qua chậm hơn khoảng 2 giây. Khách chờ lâu sau khi bấm hoàn
tiền. Endpoint chỉ nhận yêu cầu và trả `202`; việc gọi cổng thanh toán chạy
sau, ở Payments, nên chậm ở đây là chậm trong api.

### Xác nhận

1. Tỉ lệ chậm: `job:refund_requests_slow:ratio_rate5m` và `..._rate1h`.
2. Lượng request: yêu cầu hoàn tiền ít, nên vài request chậm đã là tỉ lệ lớn;
   xem số request trong 1 giờ trước khi kết luận
   (`sum(increase(http_request_duration_seconds_count{endpoint="api/v1/orders/{id:int}/refund"}[1h]))`).
3. PostgreSQL và RabbitMQ chạy; outbox của api không ứ.

### Bước 1: có thay đổi gần đây thì revert

Như `product-reads-burn.md`: commit đổi api trong hai giờ trước thì revert;
canary đang chạy thì trọng số về 0.

### Bước 2: không có thay đổi gần đây

Xem truy vấn chậm và khóa trên bảng `orders` (yêu cầu hoàn tiền đọc và cập
nhật đơn), và log của api theo trace id.

### Khi nào chuyển cấp

Sau 15 phút (giả định) mà tỉ lệ 5 phút chưa giảm. Hoàn tiền là việc nhạy cảm
với kế toán: báo product owner khi sự cố kéo dài quá 30 phút. Thứ tự gọi:
`docs/team/on-call.md`.

### Ghi lại

Dòng thời gian theo `docs/team/incident-response.md`; postmortem khi sự cố tiêu
hơn một phần tư budget của S4.

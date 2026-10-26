# Runbook: OrderPlacementLatencyFastBurn

Alert: `OrderPlacementLatencyFastBurn` (`severity: page`), rule trong
`deploy/gitops/config-repo/platform/monitoring/rules/slo.rules.yml`. SLI S2
của `docs/design/slo.md`: đặt đơn đủ nhanh (trả lời trong bucket 0,512 giây).

### Ý nghĩa với khách

Hơn 13,44% lượt đặt đơn trong cả 1 giờ lẫn 5 phút qua chậm hơn 0,512 giây.
Khách chờ lâu khi bấm đặt, có người bấm lại; idempotency key giữ cho họ khỏi
đặt hai đơn.

### Xác nhận

1. Tỉ lệ chậm: `job:order_placement_slow:ratio_rate5m` và `..._rate1h`.
2. p95 theo Pod:
   `histogram_quantile(0.95, sum by (app, le) (rate(http_request_duration_seconds_bucket{method="POST", endpoint=~"api/v[12]/orders"}[5m])))`.
3. Chậm ở mọi Pod hay một Pod; Pod có bị giới hạn CPU không (dashboard).

### Bước 1: có thay đổi gần đây thì revert

Như `product-reads-burn.md`: commit đổi api trong hai giờ trước thì revert;
canary đang chạy thì trọng số về 0.

### Bước 2: không có thay đổi gần đây

Xem PostgreSQL (truy vấn chậm, khóa, kết nối gần `max_connections`) và lượng
request so với `docs/design/capacity-plan.md`; tăng replica bằng một commit nếu
lượng request vượt kế hoạch.

### Khi nào chuyển cấp

Sau 15 phút (giả định) mà tỉ lệ 5 phút chưa giảm, hoặc khi đặt đơn bắt đầu lỗi
(S1). Thứ tự gọi: `docs/team/on-call.md`.

### Ghi lại

Dòng thời gian theo `docs/team/incident-response.md`; postmortem khi sự cố tiêu
hơn một phần tư budget của S2.

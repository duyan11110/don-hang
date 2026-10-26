# Runbook: OrderPlacementFastBurn

Alert: `OrderPlacementFastBurn` (`severity: page`), rule trong
`deploy/gitops/config-repo/platform/monitoring/rules/slo.rules.yml`. SLI S1
của `docs/design/slo.md`: đặt đơn không lỗi.

### Ý nghĩa với khách

Một phần đáng kể lượt đặt đơn (`POST` `api/v1/orders`, `api/v2/orders`) trả
`5xx`: tỉ lệ 1 giờ và 5 phút đều trên 6,72%. Cửa hàng mất đơn; S1 cũng là SLI
của SLA với cửa hàng.

### Xác nhận

1. Tỉ lệ xấu: `job:order_placement_bad:ratio_rate5m` và `..._rate1h` trong
   Prometheus của staging.
2. Mã lỗi và Pod: `sum by (app, code) (rate(http_requests_received_total{method="POST", endpoint=~"api/v[12]/orders"}[5m]))`.
3. `429` không tính là xấu: nếu chỉ thấy `429`, giới hạn `orders` đang làm
   đúng việc, không phải sự cố.
4. Pod api Ready, PostgreSQL và RabbitMQ chạy (`kubectl get pods -n donhang`).

### Bước 1: có thay đổi gần đây thì revert

Như `product-reads-burn.md`: xem `git log -n 5 -- envs/staging` của repo cấu
hình, revert commit đổi api trong hai giờ trước, đặt trọng số canary về 0 nếu
đang có canary.

### Bước 2: không có thay đổi gần đây

Xem log của api cho các request lỗi (trace id), và trạng thái PostgreSQL (kết
nối, dung lượng), nơi lệnh đặt đơn ghi đơn và dòng outbox.

### Khi nào chuyển cấp

Đặt đơn lỗi cho mọi cửa hàng là SEV1: gọi trưởng nhóm ngay. Còn lại: sau 15
phút (giả định) mà tỉ lệ 5 phút chưa giảm. Thứ tự gọi: `docs/team/on-call.md`.

### Ghi lại

Dòng thời gian theo `docs/team/incident-response.md`; postmortem khi sự cố tiêu
hơn một phần tư budget của S1.

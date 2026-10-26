# Runbook: ProductReadsFastBurn

Alert: `ProductReadsFastBurn` (`severity: page`), rule trong
`deploy/gitops/config-repo/platform/monitoring/rules/slo.rules.yml`. SLI S3
của `docs/design/slo.md`: đọc sản phẩm không lỗi. Đã chạy thử trong diễn tập
`scripts/devops/incident-drill.sh`.

### Ý nghĩa với khách

Khách mở danh sách sản phẩm hay một sản phẩm thì một phần đáng kể lượt mở báo
lỗi: tỉ lệ lỗi cả 1 giờ lẫn 5 phút qua đều trên 6,72%. Với tốc độ này, error
budget 28 ngày của S3 hết trong khoảng 50 giờ. Khách không đặt được đơn cho sản
phẩm họ không xem được.

### Xác nhận

1. Prometheus của staging: tỉ lệ xấu 5 phút và 1 giờ.

   ```
   job:product_reads_bad:ratio_rate5m
   job:product_reads_bad:ratio_rate1h
   ```

   Hỏi bằng `kubectl exec -n monitoring deployment/prometheus -- promtool query instant http://localhost:9090 '<biểu thức>'`.
2. Lỗi là `503` hay `5xx` khác:

   ```
   sum by (app, code) (rate(http_requests_received_total{method="GET", endpoint=~"api/v1/products.*"}[5m]))
   ```

   `503` là giới hạn `catalog-reads` từ chối (không đủ chỗ đọc cùng lúc); `500`
   là lỗi trong api hay ở thứ api gọi (PostgreSQL, Redis).
3. Lỗi chỉ ở một `app` (ví dụ `api-canary`) hay ở mọi Pod api.
4. Các Pod api có Ready không: `kubectl get pods -n donhang -l app=api`.

### Bước 1: có thay đổi gần đây thì revert

Giảm thiểu trước, tìm nguyên nhân sau. Xem các commit gần đây của
`envs/staging` (hoặc `envs/production`) trong repo cấu hình:

```
git log --format='%h %ad %an: %s' --date=relative -n 5 -- envs/staging
```

Có commit trong khoảng hai giờ trước khi alert bật mà đổi api (image, cấu
hình, biến môi trường, số replica): `git revert` commit đó và push, như
`devops.l3.rollback-by-revert`. Đang có canary thì đặt trọng số `api-canary` về
0 trước (`docs/design/canary-checks.md`). Không sửa tay Deployment trên
cluster: Argo CD sẽ đưa nó về theo Git, và người khác không biết đã đổi gì.

Sau revert, chờ rollout xong (`kubectl rollout status deployment/api -n donhang`)
và xem tỉ lệ 5 phút giảm. Alert hết khi tỉ lệ 5 phút xuống dưới ngưỡng, trong
khi tỉ lệ 1 giờ có thể còn trên ngưỡng một lúc: đó là đúng thiết kế.

### Bước 2: không có thay đổi gần đây

- `503` nhiều mà không có thay đổi: lượng đọc tăng vượt giới hạn `catalog-reads`
  của số Pod hiện có. Tăng replica của api bằng một commit (kiểm
  `max_connections` theo `docs/design/capacity-plan.md`).
- `500`: xem log của api theo trace id, và trạng thái PostgreSQL, Redis.
- Không rõ: chuyển cấp, đừng thử nhiều thay đổi cùng lúc.

### Khi nào chuyển cấp

- Sau 15 phút (giả định) từ khi xác nhận mà tỉ lệ 5 phút chưa giảm.
- Khi đặt đơn cũng lỗi (S1): sự cố thành SEV1, gọi trưởng nhóm ngay.
- Khi bước cần làm nằm ngoài runbook này.

Thứ tự gọi: `docs/team/on-call.md`.

### Ghi lại

Ghi dòng thời gian từ lúc xác nhận: điều thấy được, quyết định, việc đã làm,
mỗi dòng có giờ (`docs/team/incident-response.md`). Sự cố tiêu hơn một phần
tư budget của S3 phải có postmortem (`docs/postmortems/template.md`).

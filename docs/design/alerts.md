# Thiết kế: alert của Đơn Hàng

Trạng thái: dùng từ stage-4, trên staging. Áp dụng cho DonHang.Api. Tài liệu
ghi mọi alert, điều kiện và ngưỡng của chúng viết thành số, alert nào gọi
người ngay và alert nào chờ giờ làm việc. SLI, SLO và chính sách error budget
ở `slo.md`; tài liệu này không đặt lại chúng.

### Alert theo triệu chứng

Alert gọi người theo thứ khách cảm thấy: các SLI S1–S4 trong `slo.md`. Nguyên
nhân nào làm khách gặp lỗi hay chậm (database, Redis, một bản phát hành, một
cấu hình sai) cũng làm SLI xấu đi, nên alert theo SLI bắt được cả những nguyên
nhân không ai liệt kê trước. Nguyên nhân không chạm tới khách thì alert im.

Không alert theo CPU, bộ nhớ hay Pod khởi động lại. Những số đó lên xuống mà
khách không thấy gì, và alert theo chúng dạy người trực bỏ qua alert. Chúng
nằm trên dashboard (`deploy/monitoring/grafana/dashboards/donhang-api.json`):
người nhận alert theo triệu chứng mở dashboard để tìm vì sao.

Rule nằm trong `deploy/gitops/config-repo/platform/monitoring/rules/slo.rules.yml`,
Prometheus của staging đánh giá chúng. Đội không dùng alert của Grafana: rule
nằm cùng chỗ với cấu hình Prometheus, được kiểm và test trong CI
(`scripts/devops/alert-rules-test.sh`).

### Burn rate

Burn rate là phần request xấu chia cho phần SLO cho phép xấu (1 − SLO). Burn
rate 1 tiêu hết error budget đúng vào cuối cửa sổ của SLO.

Cửa sổ SLO của Đơn Hàng là 28 ngày, tức 672 giờ. Hai mức đội chọn:

- Nhanh: tiêu 2% budget trong 1 giờ. Burn rate = 0,02 × 672 / 1 = 13,44. Giữ
  tốc độ này, budget 28 ngày hết trong khoảng 50 giờ.
- Chậm: tiêu 5% budget trong 6 giờ. Burn rate = 0,05 × 672 / 6 = 5,6. Giữ tốc
  độ này, budget hết trong 5 ngày.

Đây là lựa chọn của dự án, tính lại cho cửa sổ 28 ngày, không phải chuẩn
chung. Ngưỡng của một SLI là burn rate × (1 − SLO), ví dụ S3 (SLO 99,5%):
13,44 × 0,5% ≈ 6,7% request đọc sản phẩm lỗi.

Mỗi mức xét hai cửa sổ cùng lúc. Cửa sổ dài (1 giờ, 6 giờ) bỏ qua một đợt lỗi
ngắn; cửa sổ ngắn (5 phút, 30 phút) làm alert hết sớm sau khi lỗi dừng, thay vì
đợi cửa sổ dài trôi qua.

### Alert theo SLI

Mỗi SLI có hai alert. Tỉ lệ xấu ở mỗi cửa sổ là một recording rule, tên dạng
`job:<sli>:ratio_rate<cửa sổ>`, cộng mọi Pod api mà Prometheus scrape (`api`,
`api-canary`, `api-green`).

| Alert | SLI | Cửa sổ dài / ngắn | Ngưỡng | Giữ trong | Mức | Runbook |
|---|---|---|---|---|---|---|
| `OrderPlacementFastBurn` | S1, `job:order_placement_bad` | 1 giờ / 5 phút | 13,44 × 0,5% = 6,72% | 2 phút | page | `docs/runbooks/order-placement-burn.md` |
| `OrderPlacementSlowBurn` | S1 | 6 giờ / 30 phút | 5,6 × 0,5% = 2,8% | 15 phút | ticket | |
| `OrderPlacementLatencyFastBurn` | S2, `job:order_placement_slow` | 1 giờ / 5 phút | 13,44 × 1% = 13,44% | 2 phút | page | `docs/runbooks/order-placement-latency-burn.md` |
| `OrderPlacementLatencySlowBurn` | S2 | 6 giờ / 30 phút | 5,6 × 1% = 5,6% | 15 phút | ticket | |
| `ProductReadsFastBurn` | S3, `job:product_reads_bad` | 1 giờ / 5 phút | 13,44 × 0,5% = 6,72% | 2 phút | page | `docs/runbooks/product-reads-burn.md` |
| `ProductReadsSlowBurn` | S3 | 6 giờ / 30 phút | 5,6 × 0,5% = 2,8% | 15 phút | ticket | |
| `RefundRequestsFastBurn` | S4, `job:refund_requests_slow` | 1 giờ / 5 phút | 13,44 × 1% = 13,44% | 2 phút | page | `docs/runbooks/refund-requests-burn.md` |
| `RefundRequestsSlowBurn` | S4 | 6 giờ / 30 phút | 5,6 × 1% = 5,6% | 15 phút | ticket | |

Một alert bật khi tỉ lệ xấu ở cả hai cửa sổ vượt ngưỡng và giữ như vậy trong
thời gian ở cột "Giữ trong". Mức `page` gọi người trực ngay (`on-call.md`);
mức `ticket` thành việc trong backlog, xử lý trong giờ làm việc. Mỗi alert
`page` có runbook; annotation `runbook` của rule ghi đường dẫn file đó.

### Alert theo nguyên nhân

Một số nguyên nhân không làm SLI xấu ngay nhưng cần người xem. Chúng chỉ ở mức
`ticket`, và hiện chưa chạy:

| Alert dự kiến | Điều kiện | Mức | Vì sao chưa chạy |
|---|---|---|---|
| Dead-letter queue có message | `rabbitmq_detailed_queue_messages_ready{queue=~".*[.]dead"} > 0` trong 10 phút | ticket | Chỉ Prometheus của Compose scrape RabbitMQ; Prometheus của staging chỉ scrape các Pod api |
| Restore test thất bại | Lần chạy gần nhất của `scripts/devops/restore-test.sh` thất bại | ticket | Restore test chưa chạy theo lịch, chỉ chạy tay |
| Job migration hay backup lỗi | Job `db-backup` hay hook migration kết thúc lỗi | ticket | Staging chưa thu thập trạng thái object của cluster (cần một công cụ thu thập mới) |

Bật các alert này cần staging scrape RabbitMQ, hoặc thêm công cụ thu thập
trạng thái object của cluster; đội không làm ở V1.

### Chưa có

- Gửi thông báo: Prometheus giữ trạng thái của alert (pending, firing) nhưng
  không gửi thông báo cho ai. Staging chưa chạy thành phần gửi thông báo; xem
  khoảng trống trong `docs/team/on-call.md`.
- Production chưa có Prometheus, nên chưa có alert nào trên production.
- Recording rule chỉ bắt đầu ghi khi được nạp và không tự điền quá khứ: trong
  giờ đầu sau khi Prometheus khởi động lại, tỉ lệ 1 giờ chỉ tính trên phần dữ
  liệu đã có. Prometheus của staging không có volume, nên điều này xảy ra sau
  mỗi lần Pod của nó khởi động lại.

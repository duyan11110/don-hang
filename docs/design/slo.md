# Thiết kế: SLI, SLO và error budget của Đơn Hàng

Trạng thái: đã chấp nhận ở stage-4, nhóm và product owner cùng thống nhất. Áp
dụng cho DonHang.Api.

### Phạm vi và nguồn số đo

Mọi SLI đo ở DonHang.Api bằng metric của prometheus-net:
`http_requests_received_total` và `http_request_duration_seconds_bucket`,
theo nhãn `endpoint` (mẫu route, ví dụ `api/v1/orders`), `method`, `code`.

- Request hỏng trước khi tới API, ở Caddy hay ở Gateway, không được đếm.
- Lab: Prometheus (profile `monitoring`) scrape `api:8080`. Nó không có volume
  dữ liệu, nên chỉ giữ số đo từ lần khởi động gần nhất; trong lab
  `scripts/backend/slo-report.sh` đọc cửa sổ 1 giờ thay cho 28 ngày.
- Staging và production chưa có Prometheus: xem mục Chưa có.

### SLI

| SLI | Tên | Tốt | Mọi sự kiện hợp lệ |
|---|---|---|---|
| S1 | Đặt đơn không lỗi | `POST` `api/v1/orders` và `api/v2/orders` không trả `5xx` | Mọi request `POST` tới hai endpoint đó |
| S2 | Đặt đơn đủ nhanh | Request `POST` tới hai endpoint của S1 trả lời trong bucket `le="0.512"` (0,512 giây) | Như S1 |
| S3 | Đọc sản phẩm không lỗi | Hai `GET` sản phẩm (`api/v1/products`, `api/v1/products/{id:int}`) không trả `5xx`; `503` của giới hạn `catalog-reads` tính là xấu | Mọi request `GET` tới hai endpoint đó |
| S4 | Yêu cầu hoàn tiền trong 2 giây (YC-7) | `POST` `api/v1/orders/{id:int}/refund` trả lời trong bucket `le="2.048"` | Mọi request tới endpoint đó |

S4 không đo đúng 2 giây: 2 giây không phải biên của bucket nào. Hai biên gần
nhất là 1,024 và 2,048; S4 dùng 2,048, biên gần nhất phía trên, nên lỏng hơn
YC-7 một chút. Đo đúng 2 giây cần một bucket riêng ở 2 giây; stage-4 không đổi
bucket.

`429` (giới hạn `orders` theo khách) và các `4xx` khác không tính là xấu:
chúng là câu trả lời đúng cho một request sai hay quá nhiều, hệ thống đã làm
đúng việc của nó. `503` của `catalog-reads` thì khác: request hợp lệ bị từ
chối vì hệ thống không đủ chỗ, khách thấy như một lỗi.

### Câu PromQL

Cửa sổ `[28d]` cho SLO; `slo-report.sh` dùng `[1h]`.

```
# S1
sum(increase(http_requests_received_total{method="POST", endpoint=~"api/v[12]/orders", code!~"5.."}[28d]))
  / sum(increase(http_requests_received_total{method="POST", endpoint=~"api/v[12]/orders"}[28d]))
# S2
sum(increase(http_request_duration_seconds_bucket{method="POST", endpoint=~"api/v[12]/orders", le="0.512"}[28d]))
  / sum(increase(http_request_duration_seconds_count{method="POST", endpoint=~"api/v[12]/orders"}[28d]))
# S3
sum(increase(http_requests_received_total{method="GET", endpoint=~"api/v1/products.*", code!~"5.."}[28d]))
  / sum(increase(http_requests_received_total{method="GET", endpoint=~"api/v1/products.*"}[28d]))
# S4
sum(increase(http_request_duration_seconds_bucket{method="POST", endpoint="api/v1/orders/{id:int}/refund", le="2.048"}[28d]))
  / sum(increase(http_request_duration_seconds_count{method="POST", endpoint="api/v1/orders/{id:int}/refund"}[28d]))
```

### SLO

Cửa sổ: 28 ngày trượt, để mỗi cửa sổ có cùng số ngày cuối tuần.

| SLI | SLO | Nguồn |
|---|---|---|
| S1 | 99,5% | Cửa hàng bán được hàng; SLA với cửa hàng ở mục dưới |
| S2 | 99% | CH-3 trong `docs/team/multi-shop-requirements.md`: ngày đông của một cửa hàng không làm chậm cửa hàng khác |
| S3 | 99,5% | CH-3, như S2 |
| S4 | 99% | YC-7 trong `docs/team/refund-requirements.md` |

Không SLO nào là 100%. API phụ thuộc PostgreSQL, Redis, RabbitMQ, Keycloak,
và mỗi thứ đều có lúc lỗi; mục tiêu 100% không đạt được, và nó cấm mọi thay
đổi có chút rủi ro, kể cả các lần phát hành sửa lỗi.

### SLA với cửa hàng (giả định, chờ hợp đồng)

Chỉ cho S1: 99% request đặt đơn không lỗi trong mỗi tháng dương lịch. Tháng
nào thấp hơn, cửa hàng được bồi hoàn bằng tín dụng dịch vụ trừ vào kỳ sau. SLA
thấp hơn SLO có chủ ý: đội thấy vấn đề và sửa trước khi hợp đồng bị vi phạm.

### Error budget

Error budget là phần sự kiện được phép xấu trong cửa sổ: 1 − SLO, tính theo số
request. Ví dụ giả định: 200.000 request đặt đơn trong 28 ngày, SLO 99,5%,
budget là 0,5% của 200.000, tức 1.000 request lỗi. Quy ra thời gian, 0,5% của
28 ngày là khoảng 3 giờ 22 phút nếu mọi request trong thời gian đó đều lỗi.

### Chính sách

Nhóm và product owner thống nhất trước, không bàn lại trong lúc có sự cố:

- Còn budget: phát hành như thường. Một lần phát hành gây lỗi tiêu budget
  như mọi sự cố khác.
- Hết budget của một service: dừng phát hành tính năng của service đó; chỉ
  phát hành sửa lỗi và việc tăng độ tin cậy, cho tới khi SLI trong cửa sổ trở
  lại trên SLO.
- Một sự cố tiêu hơn một phần tư budget của một SLI: viết postmortem, theo
  cách làm của đội trực sự cố.

### Chưa có

- Alert theo tốc độ tiêu budget (burn rate): chưa có; SLI hiện chỉ xem được
  khi có người hỏi Prometheus.
- SLI theo từng cửa hàng: S1–S4 gộp mọi cửa hàng, nên một cửa hàng bị từ chối
  phần lớn thời gian vẫn có thể không làm SLI tụt dưới SLO (ADR 0016).
- Prometheus trên cluster staging và production: chưa có; SLO ở đây mới đo
  được trong lab.

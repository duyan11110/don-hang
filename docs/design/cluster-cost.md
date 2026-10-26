# Chi phí cluster của Đơn Hàng

Trạng thái: mô hình từ stage-4, chưa áp vào manifest. Tài liệu tính chi phí
cluster bằng số node và giờ công, không bằng tiền: mọi con số ghi "giả định"
là để so các lựa chọn, không phải giá của nhà cung cấp nào. Nó đi cùng ADR
0022 (production trên Kubernetes managed).

### Node được lấp bằng request

Scheduler đặt một Pod lên node khi phần chưa ai xin của node còn đủ cho
request của Pod. Vì thế số node một cluster cần, và phải trả tiền, đi theo
tổng request của các Pod, dù phần đã xin có được dùng hay không.

Cách tính của Đơn Hàng:

- Số node = tổng request (CPU hoặc bộ nhớ, lấy cái cần nhiều node hơn) chia
  cho phần allocatable của một node nhân mức lấp đầy mục tiêu, làm tròn lên.
- Một node: 4 CPU và 8 GiB allocatable (giả định).
- Mức lấp đầy mục tiêu: 70% (giả định), phần còn lại để rolling update và
  đỉnh tải có chỗ.
- Chi phí mỗi tháng = số node × giờ chạy + ngày công vận hành mỗi cluster
  (2 ngày công một tháng, giả định, như cột B của ADR 0022).

### Request của các workload staging

Bảng so request đang đặt trong `deploy/gitops/config-repo-kustomize/base/`
với request đề xuất. Lab không cài metrics-server nên đội chưa có số đo mức
dùng của từng Pod; request đề xuất là ước lượng (giả định), phải đo lại lúc
cao điểm trước khi sửa manifest.

| Workload | Replica | Request đang đặt (CPU / bộ nhớ) | Request đề xuất (giả định) |
|---|---|---|---|
| `api` | 2 | 250m / 256Mi mỗi Pod | giữ nguyên |
| `db` | 1 | không đặt | 500m / 1Gi |
| `rabbitmq` | 1 | không đặt | 200m / 512Mi |
| `keycloak` | 1 | không đặt | 250m / 768Mi |
| `redis` | 1 | không đặt | 50m / 128Mi |
| `notifications` | 1 | không đặt | 100m / 128Mi |
| `payments` | 1 | không đặt | 100m / 128Mi |
| `mailpit` (chỉ lab) | 1 | không đặt | 10m / 32Mi |
| `fake-gateway` (chỉ lab) | 1 | không đặt | 10m / 32Mi |
| Tổng | | 500m / 512Mi | 1720m / 3264Mi |

Pod không đặt request được scheduler tính là không xin gì: node trông còn
trống trong khi các Pod đó vẫn dùng CPU và bộ nhớ thật. Tổng request đang đặt
vì thế không nói được cluster cần bao nhiêu node.

### Phần nền cố định mỗi cluster

Mỗi cluster chạy platform của nó dù có bao nhiêu traffic. Mỗi cluster hay môi
trường thêm vào lại trả phần này một lần nữa.

| Thành phần | Request đề xuất (giả định) |
|---|---|
| Argo CD (mọi thành phần của nó) | 500m / 1Gi |
| Git server | 100m / 256Mi |
| Traefik | 100m / 128Mi |
| Controller của Sealed Secrets | 50m / 64Mi |
| Prometheus (chỉ staging) | 200m / 512Mi |
| Tổng | 950m / 1984Mi |

Các manifest của những thành phần này cũng chưa đặt request. Với tổng
workload và phần nền (2670m / 5248Mi), staging vừa một node theo cách tính
trên: một node cho 2,8 CPU và 5,6 GiB ở mức lấp đầy 70%.

### Đòn bẩy

- Request: đặt theo mức dùng đo lúc cao điểm cộng một khoảng dư. Thấp quá thì
  Pod bị chậm, bị giết vì thiếu bộ nhớ, hoặc chen lấn Pod bên cạnh; cao quá
  thì node bị giữ chỗ mà không làm gì.
- `minReplicas` của HPA: production hiện chạy `api` với số replica cố định
  trong Git; với HPA, số replica lúc vắng khách giảm về `minReplicas` (xem ví
  dụ trong `cluster-review-checklist.md`).
- Môi trường tắt ngoài giờ: staging không cần chạy ban đêm. Giờ node giảm
  theo số giờ tắt; dựng lại theo các bước của `scripts/devops/dr-drill.sh`, đã
  đo thời gian.
- Thời gian giữ telemetry và tỉ lệ sampling: Tempo của lab giữ trace 24 giờ
  (`deploy/monitoring/tempo.yml`), api giữ trace với tỉ lệ
  `Telemetry:SampleRatio`, 0,1 nếu không cấu hình. Chọn hai số này theo SLO
  là việc của `cost-per-shop.md`.

Các đòn bẩy giảm số node; không đòn bẩy nào giảm phần nền cố định, trừ bớt
một cluster hay một môi trường.

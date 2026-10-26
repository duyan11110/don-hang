# Chiến lược kỹ thuật của Đơn Hàng

Kỳ hạn: một năm, từ Sprint 23 (giả định). Người viết: trưởng nhóm, cùng
product owner. Tài liệu ngắn này nói thách thức chính của hệ thống, hướng đi
đã chọn để gặp nó, và vài hành động theo sau. Nó không quyết lại các ADR mà nó
trỏ tới; nó cho thấy các ADR đó là phần của cùng một kế hoạch.

### Chẩn đoán

Đơn Hàng phải đi từ một cửa hàng lên 1.000 cửa hàng trên một nền tảng
(`multi-shop-requirements.md`; 1.000 là giả định cho ba năm). Những điểm yếu
nhất của hệ thống hôm nay cho mục tiêu đó:

- Cô lập giữa cửa hàng chưa có: không dòng dữ liệu nào biết nó thuộc cửa hàng
  nào; `multi-shop-data-rollout.md` mới là kế hoạch.
- Production chưa có giám sát: không Prometheus nào chạy ở production, nên SLO
  trong `slo.md` chưa đo được ở đó và không alert nào báo khi error budget bị
  tiêu nhanh.
- Bản sao lưu và WAL chưa rời máy đang chạy database: mất máy đó là mất cả bản
  sao lưu (ADR 0020).
- Chỉ một đội làm toàn bộ hệ thống, trong khi 1.000 cửa hàng cần ba tới bốn
  đội (giả định trong `multi-shop-requirements.md`).

### Hướng đi

- Một bản triển khai chung cho mọi cửa hàng (ADR 0012), dữ liệu của mọi cửa
  hàng trong bảng chung có `shop_id` và row-level security (ADR 0013), chạy
  trên Kubernetes managed của một nhà cung cấp (ADR 0022). Mở cửa hàng mới là
  thêm dữ liệu, không thêm một bản hệ thống.
- Một bản triển khai chung nghĩa là một bản phát hành hỏng chạm tới mọi cửa
  hàng, nên mỗi thay đổi nhỏ của api đi qua canary, và thay đổi cửa hàng thấy
  được nằm sau feature flag (ADR 0019).

### Không làm

| Không làm | Lý do | Nguồn |
|---|---|---|
| Không tách thêm service | Tách Ordering hay Catalog không trả lời yêu cầu nhiều cửa hàng nào; cùng một đội vẫn sửa chúng cùng lúc | ADR 0012 |
| Không dùng service mesh | Với ba service .NET và một nhóm, mesh lấp hai khoảng trống chưa ai yêu cầu lấp, và cái giá trả ở mọi Pod, mọi lời gọi | ADR 0021 |
| Không chạy trên cloud thứ hai | Gấp đôi platform để tránh một rủi ro mà kế hoạch rời đi đã giữ | ADR 0022 |
| Không viết lại từ đầu | Viết lại dừng giao tính năng trong lúc hệ thống cũ vẫn phải chạy; phần cũ cần thay được thay từng bước sau một lớp định tuyến, như route `/api/v1/refunds` trong `Caddyfile` và `httproutes.yaml` đưa một đường đi tới Payments trong khi phần còn lại vẫn tới api | `Caddyfile`, `deploy/gitops/config-repo/platform/edge/httproutes.yaml` |

### Hành động

| Số | Hành động | Người phụ trách (vai trò) | Tài liệu |
|---|---|---|---|
| H1 | Đưa `shop_id` vào dữ liệu qua ba lần phát hành | Lập trình viên backend | `docs/design/multi-shop-data-rollout.md` |
| H2 | Dựng production trên Kubernetes managed | Lập trình viên phụ trách nền tảng | ADR 0022, `docs/design/cluster-migration-plan.md` |
| H3 | Giám sát production: Prometheus và alert theo error budget | Lập trình viên phụ trách nền tảng | `docs/design/slo.md`, mục Chưa có |
| H4 | Sao base backup và WAL sang region thứ hai | Lập trình viên phụ trách nền tảng | ADR 0020 |
| H5 | Nối Notifications với dịch vụ gửi email | Lập trình viên backend | ADR 0024 |
| H6 | Lấp các khoảng trống trong bảng kiểm soát tuân thủ | Trưởng nhóm | `compliance-controls.md` |

Một chiến lược không có hành động chỉ là một mong muốn. Thứ tự và thời điểm
của các hành động nằm trong `roadmap.md`.

### Xem lại

Mỗi quý, cùng `roadmap.md` và bảng "Giả định cần theo dõi" của
`architecture-governance.md`. Chẩn đoán đổi (ví dụ một hợp đồng đòi bản hệ
thống riêng) thì viết lại chiến lược trước, rồi tới roadmap.

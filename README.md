# Đơn Hàng

Đơn Hàng là một hệ thống bán hàng nhỏ, cố ý đơn giản, dùng làm ví dụ cho giáo
trình Lộ Trình Architect. Khách xem sản phẩm, đăng nhập qua Keycloak và đặt
đơn; nhân viên đổi giá sản phẩm và giao đơn; khi đơn được đặt, bị hủy hay được
giao, khách nhận một email; khách yêu cầu hoàn tiền được cho đơn đã thanh
toán. Hệ thống gồm một API ASP.NET Core (`DonHang.Api`), hai service tách ra
(`DonHang.Notifications` gửi email, `DonHang.Payments` lo hoàn tiền qua cổng
thanh toán), một app Flutter chạy trên trình duyệt (`DonHang.App`),
PostgreSQL, Redis, RabbitMQ và Keycloak, tất cả chạy bằng Docker Compose trên
máy bạn. Mỗi tag `stage-N` là trạng thái của repo cho một giai đoạn của giáo
trình; file này mô tả tag `stage-3`.

## Cần có trên máy

- Docker Desktop.
- Flutter SDK 3.47: `scripts/up.sh` build app web trên máy bạn, không trong
  container.
- Bash. Trên Windows, dùng Git Bash; nó có sẵn `openssl` và `ssh-keygen` mà
  `scripts/dev-secrets.sh` cần.
- Chỉ khi chạy test: .NET SDK 10.0.300 (ghim trong `global.json`); test tích
  hợp cũng cần Docker đang chạy.
- Chỉ cho các bài Kubernetes, OpenTofu và GitOps: kind, kubectl, OpenTofu,
  kubeseal và Helm trên máy, cùng đủ bộ nhớ cho Docker (xem `STAGE.md`).
- Trên Windows và macOS, chạy test của app bằng
  `flutter test --exclude-tags golden`: ảnh golden chỉ so trên Linux.

## Chạy

1. Chạy `scripts/up.sh`. Lần đầu, nó tạo secret chỉ dùng cho máy dev trong
   `.env` và `secrets/`, build app web, rồi khởi động mọi container và chờ
   chúng sẵn sàng. Lần đầu mất vài phút vì phải tải image.
2. Mở app ở `localhost:8081` và đăng nhập bằng `anh.tran@example.com`, mật khẩu
   `donhang-dev-password` (một khách). Tài khoản nhân viên: `lan.do@example.com`,
   cùng mật khẩu.
3. Chạy lệnh của một bài: `scripts/<module>/<tên>.sh`, ví dụ
   `scripts/backend/cache-aside.sh`.
4. Dừng và xóa mọi dữ liệu: `scripts/down.sh`.

Để có thêm Prometheus, Grafana, Loki và Tempo, sau bước 1 chạy
`docker compose --profile monitoring up -d`. Profile `replica` và `pitr` dựng
bản sao và bản khôi phục của PostgreSQL cho các bài sao lưu.

| Thành phần | Địa chỉ trên máy bạn |
|---|---|
| Site tĩnh và API, qua Caddy | `localhost:8080`, API ở `/api/v1/` và `/api/v2/` |
| App Flutter web | `localhost:8081` |
| Keycloak | `localhost:8180`, trang quản trị `/admin`: user `admin`, mật khẩu `KEYCLOAK_ADMIN_PASSWORD` trong `.env` |
| Mailpit, nơi mọi email của Notifications rơi vào | `localhost:8025` |
| RabbitMQ, trang quản trị | `localhost:15672`: user `donhang`, mật khẩu `RABBITMQ_PASSWORD` trong `.env` |
| PostgreSQL | `localhost:5432`, database và user `donhang`, mật khẩu `POSTGRES_PASSWORD` trong `.env` |
| Lab box qua SSH | `ssh -p 2222 -i secrets/lab_key dev@localhost` |
| Prometheus (profile `monitoring`) | `localhost:9090` |
| Grafana (profile `monitoring`) | `localhost:3000`: user `admin`, mật khẩu `GRAFANA_ADMIN_PASSWORD` trong `.env` |

Chạy test: `dotnet test DonHang.slnx` cho API, `flutter test` trong thư mục
`DonHang.App` cho app.

## Đọc tiếp

- `STAGE.md`: hệ thống ở tag này có gì, đổi gì so với tag trước (tiếng Anh,
  viết cho người soạn bài).
- `CHANGELOG.md`: mỗi phiên bản đổi gì, cho người gọi API và dùng app.
- `/openapi/v1.json` trên `localhost:8080`: hợp đồng của API.
- `docs/`: tài liệu của đội, như `docs/team/` (sprint, story, kế hoạch và yêu
  cầu hoàn tiền) và `docs/design/`.
- `docs/adr/`: các quyết định kiến trúc (ADR), danh sách ở
  `docs/adr/README.md`.
- `docs/team/tech-debt-register.md`: nợ kỹ thuật đội đang mang và đã trả.
- `docs/team/payment-gateway-evaluation.md`: đánh giá cổng thanh toán.
- `docs/team/self-run-components.md`: thành phần đội tự chạy và việc định kỳ
  của chúng.
- `deploy/k8s/` và `scripts/k8s/`: chạy Đơn Hàng trên một cluster kind.
- `deploy/tofu/`, `deploy/gitops/` và `scripts/devops/`: cluster staging dựng
  bằng OpenTofu và triển khai bằng Argo CD.

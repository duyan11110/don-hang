# Thành phần Đơn Hàng tự chạy

Mỗi thành phần mã nguồn mở đội tự chạy không mất phí bản quyền, nhưng mang
theo việc định kỳ: nâng cấp và vá bảo mật, sao lưu và thử khôi phục, theo
dõi, dung lượng, và một người hiểu nó khi nó hỏng. Bảng dưới ghi những việc đó
ở stage-3. Phương án managed là dịch vụ do nhà cung cấp chạy thay, đổi việc
định kỳ lấy phí, ít quyền kiểm soát hơn và dữ liệu nằm trên máy của họ; bảng
không nêu tên hay giá nhà cung cấp nào.

| Thành phần | Vì sao tự chạy | Việc định kỳ | Người lo | Phương án managed |
|---|---|---|---|---|
| PostgreSQL | Dữ liệu chính của đơn, Payments, Notifications và Keycloak; đội quen nó từ đầu | Nâng cấp bản vá mỗi quý; sao lưu hằng ngày, WAL lưu liên tục, thử khôi phục mỗi tháng; theo dõi dung lượng đĩa và kết nối | Lập trình viên backend, luân phiên | Database managed: nhà cung cấp lo sao lưu, bản sao và nâng cấp |
| RabbitMQ | Chuyển message giữa API, Notifications và Payments | Nâng cấp; theo dõi độ dài queue và dead-letter queue; dữ liệu queue nằm trên volume | Lập trình viên backend | Message broker managed |
| Keycloak | Đăng nhập cho khách và nhân viên (ADR 0009) | Nâng cấp và vá bảo mật thường xuyên vì đây là cửa vào hệ thống; sao lưu realm và database của nó; xoay khóa ký | Trưởng nhóm | Dịch vụ đăng nhập trả phí (phương án C của ADR 0009) |
| Prometheus, Grafana, Loki | Số đo, dashboard và log | Nâng cấp; giới hạn thời gian giữ dữ liệu để đĩa không đầy; giữ dashboard trong Git | Lập trình viên backend | Dịch vụ giám sát managed |
| Mailpit | Bắt mọi email trong lab để xem, không gửi đi đâu | Gần như không có | Không ai: chỉ dùng trong lab | Không áp dụng: production cần một dịch vụ gửi email thật, đội chưa có, xem bên dưới |

Keycloak trong lab chạy ở chế độ phát triển (`start-dev`). Trong Compose dữ
liệu của nó nằm trong database `keycloak` của PostgreSQL chung; trong cluster
staging nó giữ dữ liệu trong chính container và mất khi Pod bị thay. Chạy thật
cần thêm chế độ khởi động production (hostname, TLS), database riêng có sao
lưu, và người theo dõi các bản vá: việc lab bỏ qua.

Gửi email cho khách là năng lực còn phải mua: Mailpit chỉ bắt email, không
gửi. Trước khi có khách thật, đội cần một dịch vụ gửi email và một lần đánh
giá như `payment-gateway-evaluation.md`.

Các thành phần tự chạy khác (Redis, Tempo, Alloy, Caddy, và trong cluster là
Argo CD, Git server, bộ điều khiển giải mã secret, bộ điều khiển nhận traffic
vào cluster) có cùng loại việc định kỳ; đội ghi chúng ở đây khi có người lo
riêng.

Dependabot (`.github/dependabot.yml`) đề xuất hằng tuần bản mới của gói
NuGet, gói Dart, action của workflow và base image trong các Dockerfile. Image
của các thành phần trong bảng, ghi trong `docker-compose.yml`, không nằm trong
danh sách đó: theo dõi bản mới và đọc ghi chú phát hành của chúng là việc của
người lo.

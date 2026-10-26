# 0019. Mỗi thành phần phát hành theo cách đường đi của nó cho phép

Trạng thái: Đã chấp nhận
Ngày: đề xuất đầu Sprint 20, quyết định cuối tuần đầu Sprint 20
Người quyết định: trưởng nhóm
Hạn góp ý: hết thứ Sáu tuần đầu Sprint 20

### Bối cảnh

Theo ADR 0012, mọi cửa hàng (1.000 cửa hàng trong kế hoạch) dùng chung một
bản triển khai. Một bản phát hành hỏng chạm tới mọi cửa hàng cùng lúc. Tới
stage-3, mọi thành phần lên staging bằng rolling update: phần request tới bản
mới tăng theo số Pod đã thay, và không ai dừng được ở giữa trừ khi revert.

Ba thành phần nhận việc theo hai đường khác nhau:

- api nhận request của khách qua Gateway (HTTPRoute `api`).
- Notifications chỉ nhận message từ RabbitMQ.
- Payments nhận các bước của saga thanh toán và hoàn tiền từ RabbitMQ; ngoài
  ra có route `/api/v1/refunds` qua Gateway để nhân viên xem các khoản hoàn
  tiền.

Cả ba dùng chung database của mình giữa bản cũ và bản mới trong lúc phát hành.

### Các phương án

- Blue-green: chạy một bộ Pod api thứ hai đủ số replica, đổi HTTPRoute sang
  bộ mới trong một commit, đổi lại nếu hỏng. Chuyển qua lại nhanh nhất. Nhưng
  trong lúc phát hành số Pod api gấp đôi, và số kết nối tới PostgreSQL mà
  `capacity-plan.md` tính cho api cũng gấp đôi.
- Canary qua Gateway: một Deployment `api-canary` nhỏ nhận một phần request
  theo trọng số của HTTPRoute, phần đó tăng theo các bước của
  `canary-checks.md`. Quay lại bằng cách đặt trọng số về 0, nhanh như
  blue-green, chỉ thêm một Pod.
- Chỉ rolling update cho mọi thành phần, như stage-3: không thêm gì, nhưng
  không dừng được ở một phần nhỏ request.

### Quyết định

- api: canary qua Gateway theo các bước và giới hạn của `canary-checks.md`.
- Notifications và Payments: rolling update. Message trong queue không đi qua
  route, nên trọng số của HTTPRoute không chia được chúng: bản cũ và bản mới
  cùng lấy message từ một queue. Route `/api/v1/refunds` của Payments ít
  request, và việc chính của Payments đi qua queue, nên đội không dựng canary
  riêng cho nó.
- Thay đổi khách nhìn thấy: deploy sau một feature flag đang tắt, rồi bật
  theo `feature-flags.md`.
- Blue-green bị từ chối: nó gấp đôi Pod api và kết nối database để có được
  cách quay lại nhanh mà canary cũng cho.

### Hệ quả

- Mỗi bản phát hành giữ schema chạy được với code của bản trước nó. Bản cũ
  và bản mới chạy cùng lúc trong mọi cách ở trên, và trong canary một khách có
  thể gặp cả hai bản trong một phiên, nên mỗi bản phải đọc được dữ liệu bản kia
  ghi. Nhờ vậy mọi bản phát hành đảo ngược được bằng cách deploy lại bản trước.
- Message giữa các service cũng vậy: bản mới đọc được message bản cũ gửi, và
  ngược lại, trong suốt thời gian rolling update.
- Phát hành gắn với chính sách error budget trong `slo.md`: khi budget của
  một service đã hết, chỉ bản sửa lỗi được phát hành, và bản sửa lỗi của api
  vẫn đi qua đủ các bước canary.
- Staging có thêm Prometheus để đếm request theo Deployment, và hai nhãn
  `api-canary`, `api-green` trong các NetworkPolicy đang liệt kê `api`.

Điều kiện mở lại:

- Một cửa hàng cần một bản triển khai riêng (mở lại cả ADR 0012).
- Một thay đổi không thể làm tương thích với bản trước, nên bản cũ và bản mới
  không chạy cùng lúc được.
- Notifications hoặc Payments bắt đầu nhận phần lớn việc qua Gateway.

### Ý kiến đã nhận

Lập trình viên backend hỏi sao không dùng blue-green cho cả Payments, vì hoàn
tiền là thứ nhạy cảm. Không: hai bộ Pod Payments vẫn cùng lấy message từ một
queue, nên blue-green không tách được bản cũ với bản mới cho phần việc qua
queue. Quyết định không đổi; câu trả lời được thêm vào mục Quyết định.

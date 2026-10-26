# 0032. Chat hỗ trợ qua WebSocket, trong service riêng `DonHang.Support`

Trạng thái: Đã chấp nhận
Ngày: đề xuất đầu Sprint 27, quyết định cuối tuần đầu Sprint 27
Người quyết định: trưởng nhóm
Hạn góp ý: hết thứ Sáu tuần đầu Sprint 27

Chưa xây ở stage-4: không có service, endpoint hay code chat nào trong repo.
Thiết kế và buổi review ở `docs/design/support-chat-design-review.md`.

### Bối cảnh

`docs/team/support-chat-requirements.md`: tin tới màn hình đang mở trong vài
giây (giả định), không mất tin khi kết nối rớt, nhân viên chỉ thấy chat của
cửa hàng mình, chat không lấy sức chứa của đặt đơn. Khoảng 200 kết nối mở cùng
lúc ở giờ đông, khoảng 1,7 tin mỗi giây (giả định). App không có cách nào để
server gửi tin tới một màn hình đang mở.

WebSocket bắt đầu bằng một request HTTP xin đổi giao thức; khi server nhận,
cùng kết nối TCP đó giữ mở và mỗi bên gửi tin lúc nào cũng được.

### Các phương án

- App hỏi lại API mỗi vài giây: không thêm gì mới, nhưng tải tăng theo số màn
  hình mở × tần suất, và một tin chờ tới một chu kỳ.
- Module chat trong `DonHang.Api`, qua WebSocket: không thêm service, nhưng kết
  nối giữ mở hàng phút dùng chung Pod, giới hạn và canary với việc nhận đơn.
- Service riêng `DonHang.Support`, qua WebSocket có sẵn của ASP.NET Core.
- SignalR, thư viện real-time của ASP.NET Core: có sẵn nối lại và chuyển tin
  giữa Pod, nhưng app cần một client SignalR cho Dart, mà ASP.NET Core không
  cung cấp.

### Quyết định

Chọn service riêng `DonHang.Support`, đi theo golden path (`golden-path.md`).

- Database riêng `donhang_support` trên server `db`, như Notifications và
  Payments. WebSocket dùng hỗ trợ có sẵn của ASP.NET Core, không thêm thư viện.
- Mỗi tin được lưu vào PostgreSQL trước (cuộc trò chuyện, cửa hàng, người
  gửi), rồi mới gửi tới các kết nối đang mở. Dòng đã lưu là bản ghi, không phải
  việc chuyển tin.
- Nhiều Pod: Pod lưu tin xong thì publish lên một kênh publish/subscribe của
  Redis (Redis có sẵn, chỉ giữ bản sao, như `redis.yaml` ghi); mỗi Pod chuyển
  tin cho các kết nối nó đang giữ.
- App nối lại thì hỏi các tin sau id cuối nó có, đọc từ database.
- Tin trả lời chưa đọc sau 5 phút (giả định) thành một message qua outbox;
  Notifications gửi email theo ADR 0027.
- Cửa hàng lấy từ access token (từ release 2); row-level security như ADR 0013.
- Endpoint đề xuất `/api/v1/conversations`, một HTTPRoute mới tới Support.
- Phát hành bằng rolling update (ADR 0019): weight của Gateway chỉ quyết kết
  nối mới đi đâu, kết nối đang mở ở lại Pod cũ tới khi Pod đó dừng.
- Hỏi lại mỗi vài giây được giữ làm đường lui khi không mở được kết nối.

### Hệ quả

- Thêm một service, một database, một HTTPRoute.
- Redis chuyển tin nhiều nhất một lần; mất chuyển tiếp thì app đọc lại từ
  database khi nối lại.
- Mỗi lần phát hành đóng kết nối của Pod bị thay; app nối lại sau một khoảng
  chờ có jitter.
- Cuộc trò chuyện và tin có chủ là Support (`data-ownership.md`).

Đội xem lại quyết định khi: app có bản cho điện thoại (push thay email cho
CT-5); ASP.NET Core có client SignalR chính thức cho Dart; số kết nối mỗi Pod
vượt khoảng dư đo được.

### Ý kiến đã nhận

Lập trình viên backend hỏi sao không để chat trong API cho đỡ một service.
Kết nối giữ lâu sẽ dùng chung Pod, giới hạn và canary với việc nhận đơn, trái
driver 4. Quyết định không đổi.

# 0011. Không bọc RabbitMQ sau một lớp trung lập

Trạng thái: Bị từ chối
Ngày: đề xuất đầu Sprint 18, quyết định cuối tuần đầu Sprint 18
Người quyết định: trưởng nhóm
Hạn góp ý: hết thứ Sáu tuần đầu Sprint 18

### Bối cảnh

Một lập trình viên đề xuất đưa mọi lời gọi RabbitMQ ra sau một interface
trung lập (gửi một message, nhận message của một hàng đợi), để sau này đổi
sang một message broker khác chỉ cần viết một bản cài đặt mới của interface
đó. Lý do được nêu là tránh phụ thuộc vào một sản phẩm.

Không yếu tố nào hiện có đòi đổi broker: RabbitMQ chạy trong Compose và trên
staging, đội vận hành nó (`docs/team/self-run-components.md`), và không yêu
cầu nào của khách hay của cửa hàng nhắc tới broker. Các service lại đang dựa
vào những tính năng riêng của RabbitMQ:

- dead-letter queue: mỗi service khai báo `x-dead-letter-exchange` cho hàng
  đợi của mình, message hỏng đi vào hàng đợi `.dead` thay vì quay vòng mãi;
- quorum queue: `x-queue-type` là `quorum`, kèm `x-delivery-limit`;
- publisher confirm: `RabbitMqPublisher` mở channel với publisher
  confirmation, nên relay chỉ đánh dấu dòng outbox đã gửi khi RabbitMQ xác
  nhận đã nhận;
- topic exchange và routing key (`order.*`, `payment.*`).

### Các phương án

- Giữ như hiện tại: code dùng thẳng `RabbitMQ.Client`, gom trong
  `DonHang.Messaging` và trong topology, consumer của từng service. Không tốn
  thêm gì; đổi broker vào ngày nào đó sẽ phải sửa đúng các file liệt kê dưới
  đây.
- Bọc hết sau một interface trung lập: đổi broker về sau chỉ cần một bản cài
  đặt mới. Nhưng interface chỉ giữ được phần chung của mọi broker, nên hoặc
  nó giấu dead-letter queue, quorum queue và publisher confirm, hoặc nó lộ
  chúng ra và không còn trung lập. Thêm một lớp mọi người phải đọc và giữ, trả
  ngay bây giờ cho một lần đổi có thể không bao giờ tới.

### Quyết định

Từ chối phương án bọc. Không yếu tố nào hôm nay cần broker khác, và lớp bọc
sẽ che chính những tính năng giữ cho message không mất và không quay vòng.
Thay vì trả trước, ADR này ghi lại những chỗ phải sửa nếu một ngày phải đổi.

Các file production dùng `RabbitMQ.Client`:

- `DonHang.Messaging/RabbitMqConnection.cs`: một kết nối mỗi process.
- `DonHang.Messaging/RabbitMqPublisher.cs`: publish có publisher confirm,
  dùng bởi relay outbox của API và của Payments.
- `DonHang.Messaging/MessageTracing.cs`: mang trace context trong header.
- `DonHang.Api/Messaging/RabbitMqTopology.cs` và
  `DonHang.Api/Messaging/PaymentEventsConsumer.cs`.
- `DonHang.Notifications/RabbitMqTopology.cs` và
  `DonHang.Notifications/OrderEventsConsumer.cs`.
- `DonHang.Payments/RabbitMqTopology.cs` và
  `DonHang.Payments/RefundRequestedConsumer.cs`.

Test trong `DonHang.Tests/Messaging/` và `DonHang.Tests/Notifications/` cũng
dùng thư viện này, để chạy với một RabbitMQ thật.

### Hệ quả

- Không thêm interface nào; người đọc thấy thẳng hàng đợi, exchange và tham
  số RabbitMQ trong code của từng service.
- Chi phí đổi broker được biết trước mà không phải trả trước: chín file ở
  trên, cộng các test dùng RabbitMQ thật.
- Đội xem lại ADR này khi một trong các điều sau xảy ra: một yêu cầu (của
  khách, của cửa hàng hay của nơi chạy hệ thống) cần một tính năng RabbitMQ
  không có; nơi chạy hệ thống chỉ cung cấp một broker khác và đội không còn tự
  vận hành RabbitMQ; hoặc số file dùng thẳng `RabbitMQ.Client` tăng tới mức
  một lần đổi không còn ước lượng được từ danh sách trên.

### Ý kiến đã nhận

Người đề xuất hỏi: nếu không bọc thì đổi broker có phải viết lại hết không.
Không: ngoài chín file trên, outbox, inbox và các handler chỉ thấy
`IOutbox`, message JSON và lời gọi của chính service; một lần đổi viết lại
các file đó, không viết lại nghiệp vụ.

# Đánh giá kiến trúc đa cửa hàng (ATAM rút gọn)

Trạng thái: đã đánh giá; các rủi ro đã chuyển cho ADR sau (mục Sau buổi
đánh giá). Mọi con số ghi "giả định" là giả định của dự án. Khác
`multi-shop-design-review.md`: tài liệu đó review một thiết kế cho phần còn
để mở; tài liệu này đánh giá kiến trúc đã chọn theo các kịch bản thuộc tính
chất lượng.

### Phạm vi

- Cách làm: ATAM rút gọn. Một buổi, với cả đội và product owner, thay vì nhiều
  buổi với nhiều bên liên quan như phương pháp đầy đủ.
- Đánh giá gì: hình dạng ADR 0012 chọn (một bản triển khai chung cho mọi cửa
  hàng) trên code stage-3: `DonHang.Api` với hai module Ordering và Catalog,
  Notifications và Payments là service riêng, các giới hạn tải trong
  `DonHang.Api/Program.cs`.
- Khi nào: cuối Sprint 18 (giả định), khi ADR 0012 vừa được chấp nhận, trước
  khi xây theo nó và trước ADR chọn cách lưu dữ liệu của từng cửa hàng.
- Không làm: không quyết lại ADR 0012, không chọn cách lưu dữ liệu, không sửa
  giới hạn tải trong buổi.

Driver lấy từ `docs/team/multi-shop-requirements.md` (CH-1 tới CH-4) và
`docs/team/refund-requirements.md` (YC-7). Mỗi yêu cầu được viết thành một
hay nhiều kịch bản có thước đo.

### Kịch bản

Mỗi kịch bản xếp hạng hai lần: quan trọng thế nào với kinh doanh (do product
owner chấm) và kiến trúc làm nó khó thế nào (do đội chấm). Chỉ kịch bản Cao ở
cả hai được phân tích trong buổi.

| Số | Từ yêu cầu | Kích hoạt | Điều kiện | Phản hồi | Thước đo (giả định) | Quan trọng | Khó |
|---|---|---|---|---|---|---|---|
| K1 | CH-3 | Một cửa hàng chạy khuyến mãi, chiếm 10% tổng số đơn trong ngày | Giờ đông nhất của cửa hàng đó; các cửa hàng khác tải như ngày thường | Đọc sản phẩm và đặt đơn của các cửa hàng khác vẫn được phục vụ | Các cửa hàng khác: dưới 0,5% đọc sản phẩm lỗi, 99% đơn trả lời trong 0,512 giây, như SLO ngày thường | Cao | Cao |
| K2 | CH-1 | Nhân viên cửa hàng A mở danh sách đơn | Vận hành bình thường, kể cả khi một truy vấn quên lọc theo cửa hàng | Chỉ thấy đơn của cửa hàng A | 0 dòng của cửa hàng khác | Cao | Cao |
| K3 | CH-2 | Cửa hàng mới ký hợp đồng | Ngày làm việc bình thường | Cửa hàng mở được mà không deploy, không migration | Mở trong ngày ký; 0 deploy | Cao | Trung bình |
| K4 | YC-7 | Khách của một cửa hàng bất kỳ gửi yêu cầu hoàn tiền | Cổng thanh toán không trả lời hoặc báo lỗi | Yêu cầu được nhận và trả lời | Trong 2 giây | Cao | Cao |
| K5 | CH-4 | Nhân viên cửa hàng A đổi tên và thương hiệu trên app | Vận hành bình thường | Cửa hàng A thấy cấu hình mới; cửa hàng khác không đổi gì | Không deploy; 0 cửa hàng khác bị đổi | Trung bình | Trung bình |
| K6 | Ngoài phạm vi | Một khách mua ở hai cửa hàng bằng một tài khoản | Hai cửa hàng cùng chạy | Khách đăng nhập một lần | Không đặt | Thấp | Trung bình |
| K7 | Câu hỏi mở | Một cửa hàng muốn khôi phục dữ liệu của riêng mình về một thời điểm | Các cửa hàng khác vẫn chạy | Chỉ dữ liệu cửa hàng đó quay lại | Chờ product owner trả lời | Trung bình | Cao |

K3 và K5 không được phân tích: hình dạng ADR 0012 chọn làm chúng dễ (cửa hàng
và cấu hình là dữ liệu), nên đội ghi chúng là bằng chứng cho điểm đánh đổi bên
dưới. K6 nằm ngoài phạm vi của `multi-shop-requirements.md`; K7 chờ câu hỏi mở
ở đó.

### So với ma trận chấm điểm có trọng số

Ma trận chấm điểm có trọng số cộng điểm của mọi tiêu chí thành một tổng cho mỗi
phương án. Buổi này giữ từng kịch bản riêng: một kịch bản hỏng nặng, như K1 với
giới hạn tải hôm nay, không thể nấp sau điểm tốt của K3 và K5. Ma trận hợp khi
cần chọn giữa nhiều phương án tương đương (như `email-service-evaluation.md`);
buổi đánh giá hợp khi đã có một hình dạng và cần biết nó hỏng ở đâu.

### Kịch bản đã phân tích

| Kịch bản | Quyết định liên quan | Xếp loại | Ghi chú |
|---|---|---|---|
| K1 | Giới hạn `catalog-reads` trong `Program.cs` | Rủi ro R1 | Đếm chung mọi người gọi của một process api: tối đa 20 lượt đọc cùng lúc và 5 lượt chờ. Một cửa hàng đông dùng hết số chỗ đó, và đọc sản phẩm của các cửa hàng khác bị từ chối `503` |
| K1 | Giới hạn `orders` trong `Program.cs` | Rủi ro R2 | Đếm theo `sub` của khách (10 đơn mỗi phút mỗi khách), không theo cửa hàng: một cửa hàng đông có nhiều khách thì không giới hạn nào dừng nó. Giới hạn này cũng chỉ gắn vào `POST /api/v1/orders` |
| K1 | Số lượt đọc cùng lúc (`PermitLimit` của `catalog-reads`) | Điểm nhạy | Thấp quá thì cửa hàng nào cũng nhận `503` sớm; cao quá thì database dùng chung chịu hết tải |
| K2 | ADR 0012 để cách lưu dữ liệu của từng cửa hàng cho một ADR sau | Rủi ro R3 | Cô lập giữa cửa hàng phụ thuộc cách lưu chưa được chọn. Buổi đánh giá chuyển câu hỏi cho ADR đó, không quyết |
| K4 | `POST /api/v1/orders/{id}/refund` lưu yêu cầu và message trong một transaction, trả `202` mà không gọi cổng; Payments gửi sang cổng sau | Không rủi ro | Yêu cầu được trả lời mà không chờ cổng, dù đến từ cửa hàng nào; YC-7 giữ như khi chỉ có một cửa hàng |
| K1, K2, K3, K5 | Một bản triển khai chung (ADR 0012) | Điểm đánh đổi | Giúp K3, K5 (mở cửa hàng và đổi cấu hình là thêm dữ liệu; deploy, migration, dashboard chạy một lần cho mọi cửa hàng), nhưng làm K1, K2 khó hơn: cô lập không có sẵn từ cách triển khai mà phải làm bên trong hệ thống |

### Chủ đề rủi ro

- Giới hạn không biết cửa hàng (R1, R2): mọi giới hạn tải hôm nay đếm theo
  process hoặc theo khách. Gom thành một chủ đề vì cả hai trỏ về cùng một quyết
  định cần xem lại: giới hạn tải phải biết cửa hàng của request.
- Cô lập dữ liệu chưa được quyết (R3).

### Việc tiếp theo

| Rủi ro | Người chịu trách nhiệm | Bước tiếp theo |
|---|---|---|
| R1, R2 | Trưởng nhóm | Đề xuất một ADR về giới hạn tải theo cửa hàng; khi xây, thêm một fitness function cho thấy một cửa hàng vượt trần không làm cửa hàng khác bị từ chối (`fitness-functions.md`, mục Chưa có phép kiểm tự động) |
| R3 | Lập trình viên backend | Đề xuất ADR chọn cách lưu dữ liệu của từng cửa hàng, kèm cách kiểm rằng một cửa hàng không đọc được dữ liệu cửa hàng khác |

`DonHang.Api/Program.cs` giữ nguyên giới hạn `catalog-reads` và `orders` tới
khi ADR cho R1, R2 được xây.

### Sau buổi đánh giá

- R3 được quyết ở ADR 0013: bảng chung có `shop_id` và row-level security.
- R1 và R2 được quyết ở ADR 0016: giới hạn theo cửa hàng chồng lên giới hạn
  chung. Giới hạn đó cần biết cửa hàng của request, có từ release 2 của
  `multi-shop-data-rollout.md`, nên ở stage-4 `Program.cs` vẫn như lúc đánh giá.
- K7 trở thành CH-6 trong `docs/team/multi-shop-open-requirements.md`.

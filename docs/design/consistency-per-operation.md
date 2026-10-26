# Thiết kế: lựa chọn nhất quán theo từng thao tác

Trạng thái: mô tả code ở stage-4, không đổi code. Mỗi thao tác nghiệp vụ ghi
hai lựa chọn: khi không tới được nguồn dữ liệu (phân vùng mạng, database
dừng) thì trả lời bằng bản sao hay từ chối; khi mọi thứ chạy bình thường thì
ưu tiên trả lời nhanh hay trả giá trị mới nhất. Chủ của từng loại dữ liệu ở
`data-ownership.md`.

### Bảng lựa chọn

| Thao tác | Dữ liệu đọc/ghi, chủ | Khi không tới được nguồn | Khi bình thường | Cơ chế hiện có | Lý do nghiệp vụ |
|---|---|---|---|---|---|
| Xem một sản phẩm (`GET /api/v1/products/{id}`) | Đọc `products`, chủ Catalog | Trả lời bằng bản sao trong Redis nếu còn; không có bản sao thì lỗi | Độ trễ thấp: bản sao có thể cũ | `ProductCache`, TTL 5 phút, xóa bản sao sau khi đổi giá | Giá hiển thị cũ vài phút là chấp nhận được |
| Danh sách sản phẩm (`GET /api/v1/products`) | Đọc `products`, chủ Catalog | Từ chối (lỗi) | Mới nhất: đọc primary mỗi lần | Truy vấn thẳng `CatalogDbContext`, không cache | Nghiệp vụ chấp nhận danh sách hơi cũ; đọc primary chỉ vì code chưa có bản sao nào khác |
| Đặt đơn (`POST /api/v1/orders`, `/api/v2/orders`) | Ghi `orders`, `order_items`, `outbox_messages`, chủ Ordering; đọc giá qua `ICatalog` | Từ chối: đơn phải được lưu ở database của chủ | Ghi: mới nhất; giá: có thể là bản sao Redis | Một transaction trên primary; giá qua `ProductCache` | Đơn đã nhận phải còn; giá lúc đặt xem mục dưới |
| Xem đơn của mình (`GET /api/v1/orders/{id}`, `.../history`) | Đọc `orders`, `order_status_history`, chủ Ordering | Từ chối | Mới nhất: đọc primary | Đọc primary | Khách vừa đặt đơn phải thấy ngay đơn đó |
| Yêu cầu hoàn tiền (`POST /api/v1/orders/{id}/refund`) | Ghi `orders` (`refunding`) và outbox; Payments ghi `payments` rồi gọi cổng | Database lỗi: từ chối. Cổng lỗi: vẫn nhận, đơn ở `refunding` | Trả lời nhanh (YC-7); kết quả tới sau | Outbox, saga, trạng thái `refunding` | Không bao giờ báo đã hoàn tiền trước khi cổng xác nhận |
| Email đơn hàng | Notifications đọc email, tên trong message | Email chờ trong hàng đợi, đặt đơn không bị chặn | Email tới sau, dùng email lúc đặt đơn | Outbox, RabbitMQ, bảng `notifications` có thử lại | Email trễ vài phút không làm hỏng đơn |

### Giá lúc đặt đơn

`OrderService` hỏi giá qua `IProductPrices`, tới `ICatalog.FindAsync`, nên giá
đi qua `ProductCache`. Nếu lệnh xóa bản sao sau khi đổi giá bị lỡ (Redis lỗi
đúng lúc đó), đơn đặt trong thời gian còn lại của TTL dùng giá cũ, tối đa 5
phút. Đội chấp nhận điều này và không đổi code: khách thấy đúng giá đó trên
trang sản phẩm, giá được ghi vào `order_items.unit_price_vnd` thành dữ kiện
của đơn, và đổi giá là việc hiếm của nhân viên. Nếu một cửa hàng cần giá đổi
có hiệu lực ngay cho đơn, đặt đơn phải đọc giá từ primary.

### Hoàn tiền

API trả `202` khi đã ghi `refunding`, không chờ cổng. Đơn chỉ chuyển sang
`cancelled` khi Payments nhận xác nhận của cổng và gửi `payment.refunded`;
cổng từ chối thì đơn quay về `paid`. Không bước nào báo khách đã hoàn tiền
khi cổng chưa xác nhận.

### Nếu chuyển đọc sang replica

Ở stage-4 API không đọc `db-replica`: nó chỉ có một connection string,
`ConnectionStrings:Default`, trỏ tới primary. Replica nhận thay đổi không đồng
bộ, nên một lần đọc từ replica có thể chưa thấy lần ghi vừa xong, kể cả lần
ghi của chính người gọi (không có read-your-writes).

- Được phép chuyển: danh sách sản phẩm, vì nó chấp nhận dữ liệu hơi cũ và
  không ghi lại gì từ kết quả đọc.
- Không chuyển: xem đơn của mình và lịch sử của đơn; mọi lần đọc ngay sau
  một lần ghi của cùng người gọi; một sản phẩm đọc qua `ProductCache` (cả khi
  đặt đơn). Ngay sau khi đổi giá, bản sao Redis bị xóa và lần đọc kế tiếp nạp
  lại nó; nạp từ một replica chưa có giá mới sẽ đặt giá cũ trở lại Redis thêm
  trọn một TTL.

Chuyển một thao tác khác sang replica cần sửa bảng trên trước.

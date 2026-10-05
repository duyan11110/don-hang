# Thiết kế: lịch sử trạng thái của đơn hàng

Trạng thái: đã chọn và đã làm ở stage-3 (bảng `order_status_history`,
`GET /api/v1/orders/{id}/history`). Tài liệu viết lại các phương án đã cân
nhắc để người đến sau biết vì sao chọn như vậy và khi nào nên xem lại.

## Nhu cầu

Khách và nhân viên muốn xem một đơn đã qua những trạng thái nào, vào lúc nào:
đặt, hủy, giao. Đến stage-2 câu hỏi này không trả lời được: mỗi lần đổi trạng
thái ghi đè `orders.status`, dòng của đơn chỉ còn trạng thái cuối. Nhu cầu chỉ
là một danh sách cho từng đơn, cũ trước mới sau. Không ai cần biết cả đơn
(các dòng hàng, tổng tiền) trông thế nào ở một thời điểm trong quá khứ.

## Phương án A: event sourcing cho `Order`

Lưu `Order` thành chuỗi event của nó thay cho dòng trong `orders`; trạng thái
hiện tại tính lại từ các event mỗi lần cần.

- Được: lịch sử đầy đủ, dựng lại được đơn ở bất kỳ phiên bản nào.
- Mất: mọi use case, truy vấn và test đang nạp và lưu `Order` qua EF Core phải
  đổi (`OrderService`, `EfOrderRepository`, danh sách đơn, kiểm tra `xmin`,
  outbox). Mỗi truy vấn cần một projection. Event cũ phải đọc được mãi sau khi
  code đổi. Cả đội phải học một cách lưu dữ liệu mới.
- Thử trên mẫu trong bộ nhớ: `samples/DonHang.Samples/Samples/Design/EventSourcing/`.

## Phương án B: read model cập nhật từ domain event (chọn)

`Order` vẫn lưu theo trạng thái. Handler `RecordOrderStatusHistory` nhận mọi
domain event của `Order` và thêm một dòng vào `order_status_history` trước
`SaveChangesAsync`, trong cùng transaction với thay đổi của đơn.

- Được: lịch sử không bao giờ chậm hơn trạng thái của đơn; `Order` không biết
  bảng này tồn tại; không use case nào phải đổi.
- Mất: thêm một lệnh INSERT mỗi lần đổi trạng thái. Đơn có trước stage-3 chỉ có
  một dòng `placed` (lấy từ `placed_at`): các thay đổi giữa chừng đã bị ghi đè,
  không lấy lại được.

## Phương án C: đọc bảng `outbox_messages`

Mỗi thay đổi trạng thái đã có một dòng outbox để gửi cho service khác, nên đọc
lại bảng đó là đủ?

- Không: dòng outbox chỉ mang thứ service nhận cần (email, tên khách), được
  viết cho người nhận chứ không cho việc tra lịch sử, và đơn có trước stage-3
  không có dòng nào. Một màn hình dựa vào nó sẽ hỏng khi hình dạng message đổi.

## Quyết định

Chọn B. Nhu cầu là một danh sách cho từng đơn; B đáp ứng đúng nhu cầu đó với
một bảng và một handler. A đổi cách mọi use case của stage-3 nạp và lưu đơn để
lấy một khả năng chưa ai cần. C dựa vào dữ liệu được viết cho mục đích khác.

## Khi nào xem lại

- Có yêu cầu cho biết cả đơn trông thế nào ở một thời điểm bất kỳ trong quá
  khứ, không chỉ trạng thái.
- Nhiều read model mới cùng cần các thay đổi của đơn, và mỗi cái lại cần một
  handler riêng.
- Kiểm toán đòi chứng minh lịch sử chưa từng bị sửa.

Khi đó cân nhắc event sourcing riêng cho `Order`; các aggregate khác vẫn có
thể lưu theo trạng thái.

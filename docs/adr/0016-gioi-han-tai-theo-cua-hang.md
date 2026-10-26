# 0016. Giới hạn tải theo cửa hàng, chồng lên giới hạn chung

Trạng thái: Đã chấp nhận
Ngày: đề xuất giữa Sprint 20, quyết định cuối Sprint 20
Người quyết định: trưởng nhóm, cùng product owner
Hạn góp ý: hết thứ Sáu tuần thứ hai Sprint 20

### Bối cảnh

ADR 0013 để mở vấn đề noisy neighbor: mọi cửa hàng dùng chung kết nối
database và giới hạn tải. Buổi đánh giá kiến trúc đa cửa hàng
(`docs/design/multi-shop-architecture-review.md`) ghi rủi ro cụ thể với CH-3
("ngày đông của một cửa hàng không làm chậm cửa hàng khác"):

- `catalog-reads` đếm chung mọi người gọi của một process: một cửa hàng đông
  dùng hết 20 chỗ và 5 chỗ chờ, đọc sản phẩm của các cửa hàng khác bị từ chối
  `503`.
- `orders` đếm theo `sub` của khách, không theo cửa hàng.

SLI trong `docs/design/slo.md` gộp mọi cửa hàng, nên một cửa hàng bị từ chối
phần lớn thời gian vẫn có thể không kéo SLI xuống dưới SLO.

### Các phương án

- Giữ giới hạn chung như hiện tại: không tốn gì, rủi ro trên còn nguyên.
- Thêm giới hạn đếm theo cửa hàng bên trong API, chồng lên giới hạn chung:
  mỗi cửa hàng chỉ dùng tối đa một phần cố định của số lần đọc đồng thời mỗi
  process; giới hạn chung vẫn giữ để bảo vệ database.
- Tách cửa hàng lớn ra database hoặc bản triển khai riêng: cô lập mạnh nhất
  cho cửa hàng đó, nhưng chỉ giúp những cửa hàng đã biết là lớn, và mỗi lần
  tách là một việc chuyển dữ liệu.

### Quyết định

Chọn phương án thứ hai. Mỗi cửa hàng có một trần: một phần cố định của số lần
đọc đồng thời mỗi process (giả định một phần tư của 20). Trần không phải chỗ
giữ riêng: phần một cửa hàng không dùng vẫn để các cửa hàng khác dùng, nên
1.000 cửa hàng không chia nhỏ dung lượng thành 1.000 phần.

Thêm một counter số request theo kết quả (được phục vụ, bị từ chối theo cửa
hàng, bị từ chối theo giới hạn chung) có nhãn cửa hàng, để thấy một cửa hàng bị
từ chối dù SLI chung vẫn tốt. Không thêm nhãn cửa hàng vào histogram thời gian
trả lời: 1.000 cửa hàng nhân với mọi bucket, endpoint và mã trả lời là quá
nhiều series.

### Hệ quả

- Một cửa hàng đông chỉ chạm trần của nó; các cửa hàng khác vẫn còn chỗ trong
  giới hạn chung.
- Giới hạn cần biết cửa hàng của request, lấy từ access token, có từ release 2
  của `docs/design/multi-shop-data-rollout.md`. Trước đó không làm được:
  `Program.cs` giữ nguyên giới hạn `orders` và `catalog-reads` ở stage-4.
- Mỗi process đếm riêng, như giới hạn hiện có; nhiều Pod thì trần thực của một
  cửa hàng nhân theo số Pod.

Đội xem lại khi một cửa hàng thường xuyên cần nhiều hơn phần của mình: chuyển
cửa hàng đó sang phương án thứ ba, theo điều kiện xem lại của ADR 0013.

### Ý kiến đã nhận

Product owner hỏi cửa hàng trả nhiều hơn có được trần cao hơn không. Có thể,
khi có gói dịch vụ: trần là một con số theo cửa hàng, không phải một hằng số
trong code. Gói dịch vụ nằm ngoài ADR này.

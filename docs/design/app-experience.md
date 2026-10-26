# Thiết kế: đo trải nghiệm của khách trên DonHang.App

Trạng thái: kế hoạch ở stage-4, chưa thu số đo nào. Áp dụng cho DonHang.App.

### Đo ở phòng lab và đo trên máy khách

Đội đã đo app ở phòng lab: chạy ở profile mode trên máy của đội để tìm code
chậm, và xem kích thước bundle bằng
`scripts/frontend/web-bundle.sh`. Các số đó đo trên máy, trình duyệt và mạng
của đội. Chúng không nói app chạy thế nào trên điện thoại, trình duyệt và
đường mạng của khách, nơi máy yếu hơn, mạng chậm hơn và lỗi xảy ra mà đội
không thấy.

Đo trên máy khách là thu số đo từ máy của khách thật trong lúc họ dùng app.
Lỗi trên máy khách có thể không bao giờ tới server: ở bản release, một widget
mà `build` ném lỗi hiện thành một vùng xám, phần còn lại của app vẫn chạy, nên
khách gặp một màn hình hỏng mà API vẫn trả lời bình thường.

### Chỉ số phía app

| Chỉ số | Tên | Định nghĩa | Mục tiêu |
|---|---|---|---|
| A1 | Phiên không có lỗi | Tỉ lệ phiên kết thúc mà không có lỗi nào không được bắt | 99,5% phiên trong 28 ngày (giả định) |
| A2 | Thời gian tới màn hình đầu tiên | Từ lúc trình duyệt bắt đầu tải trang tới khi app vẽ màn hình đầu tiên, trên trình duyệt của khách | Percentile 75 dưới 3 giây, percentile 95 dưới 6 giây (giả định) |
| A3 | Đơn kẹt trong hàng đợi offline | Số đơn trong hàng đợi offline chưa tới được API sau 30 phút kể từ lúc đặt | Dưới 0,1% số đơn đặt (giả định) |

Ba chỉ số đặt cạnh các SLI của server trong `slo.md`: S1–S4 đo những request
đã tới API, A1–A3 đo những gì xảy ra trước đó, trên máy khách. Một đơn kẹt
trong hàng đợi (A3) không bao giờ thành request hỏng ở S1.

Mục tiêu là giả định cho tới khi có số đo thật: đội đặt lại mục tiêu sau 28
ngày thu số đầu tiên.

### Cách thu dự kiến

- Lỗi: Flutter đưa lỗi nó bắt trong lúc build, layout và paint tới
  `FlutterError.onError`, và lỗi ngoài các callback đó tới
  `PlatformDispatcher.instance.onError`. App gán cả hai trong `main.dart`, ghi
  lỗi vào phiên hiện tại rồi vẫn để Flutter xử lý như cũ.
- Phiên: mỗi lần mở app là một phiên, có một id ngẫu nhiên, không gắn với
  khách; khi phiên kết thúc (trang bị đóng hay ẩn) app gửi một báo cáo cho
  phiên đó: có lỗi hay không, thời gian tới màn hình đầu tiên, số đơn đang
  chờ trong hàng đợi và tuổi của đơn cũ nhất.
- Báo cáo đi tới một endpoint công khai mới của API. Endpoint đó cần giới hạn
  tải riêng, vì ai cũng gọi được nó.

### Khoảng trống

- Stage-4 chưa thu gì: không có code thu số đo trong app, không có endpoint
  nhận báo cáo.
- Giới hạn tải trong `Program.cs` không đổi ở stage-4; endpoint nhận báo cáo
  chờ tới khi có giới hạn cho nó.
- Cho tới khi app gửi số đo, các SLI của server trong `slo.md` là những số duy
  nhất đội theo dõi; lỗi chỉ xảy ra trên máy khách vẫn không ai thấy.

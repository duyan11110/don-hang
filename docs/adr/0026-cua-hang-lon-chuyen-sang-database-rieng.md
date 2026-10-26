# 0026. Cửa hàng lớn chuyển sang database riêng, qua bảng ánh xạ cửa hàng

Trạng thái: Đã chấp nhận
Ngày: đề xuất đầu Sprint 24, quyết định cuối tuần đầu Sprint 24
Người quyết định: trưởng nhóm
Hạn góp ý: hết thứ Sáu tuần đầu Sprint 24

Chưa xây ở stage-4: không có code đa cửa hàng nào trong repo. Thiết kế và buổi
review ở `docs/design/multi-shop-design-review.md`.

### Bối cảnh

ADR 0013 đặt mọi cửa hàng trong bảng chung và ghi điều kiện xem lại: một cửa
hàng quá lớn so với bảng chung, hoặc phải được khôi phục riêng.
`docs/team/multi-shop-open-requirements.md` biến hai điều đó thành CH-5 (chuyển
một cửa hàng, các cửa hàng khác không thấy thay đổi) và CH-6 (khôi phục riêng
một cửa hàng). Ước lượng ở đó: cỡ cửa hàng rất chênh, cửa hàng lớn nhất có thể
giữ khoảng 10% số đơn (giả định), và dữ liệu mỗi cửa hàng trong
`donhang_notifications`, `donhang_payments` nhỏ so với trong `donhang`.

### Các phương án

- Giữ mọi cửa hàng trong bảng chung: không thêm gì. Cửa hàng lớn vẫn chia kết
  nối và database với mọi cửa hàng khác; khôi phục riêng chỉ làm được bằng cách
  trích dòng từ một bản khôi phục tạm.
- Database riêng cho cửa hàng lớn, qua một bảng ánh xạ theo cửa hàng: bảng
  chung vẫn là mặc định; chỉ cửa hàng chạm điều kiện mới chuyển. Mỗi database
  riêng thêm một lần chạy migration, một bản sao lưu và một pool kết nối.
- Database cho mỗi cửa hàng, hoặc một bản triển khai riêng cho mỗi cửa hàng
  lớn: cô lập mạnh nhất. Database cho mỗi cửa hàng đã bị loại ở ADR 0013 (mỗi
  migration chạy 1.000 lần); bản triển khai riêng là điều ADR 0012 giữ cho hợp
  đồng đòi nó.

### Quyết định

Chọn phương án thứ hai. Bảng `shops` (chủ là Ordering, trong `donhang`) thêm
một cột ghi database giữ dữ liệu của cửa hàng; mặc định là database chung
`donhang`. Từ release 2 của `multi-shop-data-rollout.md`, mỗi request lấy cửa
hàng từ access token, tra database của cửa hàng đó trong bảng ánh xạ, rồi mở
kết nối tới đó. Mỗi Pod giữ bảng ánh xạ trong bộ nhớ một thời gian ngắn (giả
định 30 giây).

Chỉ database của `DonHang.Api` (`donhang`) chuyển cửa hàng ra. Notifications và
Payments giữ mọi cửa hàng trong bảng chung, vì dữ liệu mỗi cửa hàng ở đó nhỏ.

Một cửa hàng chuyển khi chạm một trong hai điều kiện (giả định): giữ hơn 10%
tổng số đơn của ngày đông nhất, hoặc cần khôi phục riêng theo hợp đồng.

### Hệ quả

- Bảng ánh xạ là phụ thuộc của mọi request: không đọc được nó thì không biết
  database nào.
- Mỗi migration chạy thêm một lần cho mỗi database riêng; một lần phát hành có
  thể để một database đi sau, nên migration giữ cách expand và contract.
- Mỗi database riêng có bản sao lưu và khôi phục riêng; khôi phục cửa hàng đó
  là khôi phục database của nó.
- Kết nối: số Pod × kết nối mỗi Pod × số database trên một server phải nhỏ hơn
  `max_connections`; quy tắc của `capacity-plan.md` nhân thêm số database.
- Đội chỉ chờ một vài database riêng, không hàng trăm.

Đội xem lại quyết định khi:

- Số database riêng vượt khoảng 10 (giả định): chi phí migration và kết nối lại
  gần phương án database cho mỗi cửa hàng.
- Một cửa hàng đã chuyển vẫn cần cô lập nhiều hơn database (ví dụ hợp đồng đòi
  bản riêng): điều kiện xem lại của ADR 0012.
- Notifications hay Payments có dữ liệu mỗi cửa hàng lớn tới mức phải chuyển
  theo.

### Ý kiến đã nhận

Lập trình viên backend hỏi sao không chuyển luôn Notifications và Payments
cho đủ bộ. Ước lượng cho thấy dữ liệu mỗi cửa hàng ở đó nhỏ, và chuyển theo
là nhân ba số database phải migrate và sao lưu; điều kiện xem lại thứ ba giữ
trường hợp đó. Quyết định không đổi.

# 0012. Phục vụ mọi cửa hàng từ một bản triển khai chung

Trạng thái: Đã chấp nhận
Ngày: đề xuất giữa Sprint 18, quyết định cuối Sprint 18
Người quyết định: trưởng nhóm, cùng product owner
Hạn góp ý: hết thứ Sáu tuần thứ hai Sprint 18

### Bối cảnh

Đơn Hàng sẽ phục vụ 1.000 cửa hàng (`docs/team/multi-shop-requirements.md`).
Bốn yêu cầu mới định hình quyết định: mỗi cửa hàng chỉ thấy dữ liệu của mình
(CH-1), mở cửa hàng không cần deploy (CH-2), ngày đông của một cửa hàng không
làm chậm cửa hàng khác (CH-3), cấu hình theo từng cửa hàng (CH-4). Hoàn tiền,
email và quy tắc đơn không đổi trong mỗi cửa hàng. Một đội làm toàn bộ hệ
thống hôm nay, ba tới bốn đội khi đủ 1.000 cửa hàng (giả định).

Ở stage-3, Đơn Hàng là một bản triển khai: `DonHang.Api` chứa hai module
Ordering và Catalog, Notifications và Payments là service riêng, mỗi service
một database trên cùng một server PostgreSQL.

### Các phương án

- Một bản toàn hệ thống cho mỗi cửa hàng: cô lập tốt nhất, một cửa hàng đông
  chỉ làm chậm chính nó (CH-1, CH-3). Nhưng mọi deploy, migration, dashboard
  và cảnh báo nhân lên 1.000 lần, và mở cửa hàng mới là dựng thêm một bản,
  tức là một lần deploy (trái CH-2).
- Một bản triển khai chung, giữ hình dạng stage-3: cửa hàng trở thành dữ liệu
  bên trong hệ thống. Mở cửa hàng là thêm dữ liệu (CH-2), cấu hình là dữ liệu
  (CH-4); deploy và migration chạy một lần cho mọi cửa hàng. Cô lập (CH-1,
  CH-3) không còn có sẵn từ cách triển khai mà phải làm bên trong hệ thống.
- Tách thêm Ordering và Catalog thành service: không trả lời yêu cầu nào ở
  trên, vì cửa hàng vẫn là dữ liệu bên trong mỗi service. Cùng một đội vẫn sửa
  hai phần đó cùng lúc, nên tách ra có nguy cơ thành một distributed monolith.

### Quyết định

Chọn một bản triển khai chung, giữ hình dạng stage-3. Đây là phương án duy
nhất đáp ứng CH-2 và CH-4 mà không nhân chi phí vận hành theo số cửa hàng.
Phần nó không cho sẵn, cô lập giữa các cửa hàng, được làm bên trong hệ thống:
cách lưu dữ liệu của từng cửa hàng do một ADR sau quyết định.

### Hệ quả

- Mỗi request, mỗi dòng dữ liệu và mỗi message phải biết nó thuộc cửa hàng
  nào; cô lập dữ liệu (CH-1) dựa vào cách lưu dữ liệu mà ADR sau chọn.
- Giới hạn tải hiện có (`orders`, `catalog-reads` trong `Program.cs`) không
  biết cửa hàng; CH-3 cần xem lại chúng.
- Một lỗi hay một deploy hỏng chạm tới mọi cửa hàng cùng lúc; cách phát hành
  phải tính tới điều đó.
- Không thêm service nào; Ordering và Catalog vẫn là module trong một process.

Đội xem lại quyết định khi:

- Một cửa hàng có hợp đồng đòi một bản hệ thống riêng. Cửa hàng đó được cấp
  một bản riêng của cùng hệ thống, các cửa hàng khác vẫn được phục vụ như cũ.
- Số đội tăng tới mức các đội phải chờ nhau để sửa cùng một module; lúc đó
  ranh giới module, và có thể là service, được xem lại theo ranh giới đội.

### Ý kiến đã nhận

Product owner hỏi một cửa hàng lớn có được bản riêng ngay từ đầu không.
Không, cho tới khi hợp đồng đòi; điều kiện xem lại thứ nhất ghi trường hợp
đó, và bản riêng khi ấy không đổi cách phục vụ các cửa hàng còn lại.

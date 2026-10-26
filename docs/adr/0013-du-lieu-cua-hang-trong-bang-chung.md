# 0013. Dữ liệu của mọi cửa hàng trong bảng chung, có `shop_id` và row-level security

Trạng thái: Đã chấp nhận
Ngày: đề xuất đầu Sprint 19, quyết định cuối tuần đầu Sprint 19
Người quyết định: trưởng nhóm
Hạn góp ý: hết thứ Sáu tuần đầu Sprint 19

### Bối cảnh

ADR 0012 chọn một bản triển khai chung cho mọi cửa hàng và để lại một câu
hỏi: dữ liệu của từng cửa hàng nằm ở đâu bên trong bản triển khai đó. ADR này
không quyết lại 0012. Yêu cầu liên quan trong
`docs/team/multi-shop-requirements.md`: mỗi cửa hàng chỉ thấy dữ liệu của mình
(CH-1), mở cửa hàng không cần deploy (CH-2), ngày đông của một cửa hàng không
làm chậm cửa hàng khác (CH-3). Số cửa hàng dự kiến là 1.000 (giả định).

Mỗi service giữ database của mình (`donhang`, `donhang_payments`,
`donhang_notifications`); quyết định này áp dụng cho từng database đó.

### Các phương án

- Bảng chung, mỗi bảng chứa dữ liệu của một cửa hàng có cột `shop_id`, thêm
  row-level security: một bộ migration cho mọi cửa hàng; mở cửa hàng là thêm
  một dòng vào `shops`. Cô lập dựa vào bộ lọc `shop_id` trong code, và
  row-level security là lớp canh thứ hai khi một truy vấn quên bộ lọc.
- Một schema cho mỗi cửa hàng: cô lập theo `search_path`. Mỗi thay đổi schema
  chạy một lần cho mỗi cửa hàng: `scripts/backend/tenancy-models.sh` cho thấy
  thêm một cột là một `ALTER TABLE` cho mỗi schema. Mở cửa hàng là tạo schema
  và chạy toàn bộ migration cho nó.
- Một database cho mỗi cửa hàng: cô lập mạnh nhất, khôi phục riêng một cửa
  hàng dễ nhất. Migration cũng chạy một lần cho mỗi database, không truy vấn
  nào đọc qua hai database (`tenancy-models.sh` cho thấy lỗi
  `cross-database references are not implemented`), và mỗi database cần kết
  nối riêng từ mỗi Pod.

### Quyết định

Chọn bảng chung với `shop_id` và row-level security.

Với 1.000 cửa hàng, schema hay database riêng biến mỗi lần phát hành của một
service thành 1.000 lần chạy migration, và mỗi lần mở cửa hàng thành một việc
tạo schema hoặc database (trái CH-2). Bảng chung giữ một lần chạy migration,
và mở cửa hàng là thêm một dòng vào `shops`.

Cửa hàng của một request lấy từ access token đã được kiểm, không từ tham số
do client gửi. Code lọc mọi truy vấn theo `shop_id` đó; row-level security
theo `shop_id` là lớp canh thứ hai, để một truy vấn quên bộ lọc vẫn chỉ thấy
một cửa hàng. Thứ tự đưa `shop_id` vào từng bảng ở
`docs/design/multi-shop-data-rollout.md`.

### Hệ quả

- Mọi bảng chứa dữ liệu của một cửa hàng có `shop_id`; khóa và index bắt
  đầu bằng `shop_id`.
- Một cửa hàng đông vẫn dùng chung kết nối database và giới hạn tải với các
  cửa hàng khác (noisy neighbor). ADR này không giải quyết điều đó; giới hạn
  theo cửa hàng thuộc về kế hoạch dung lượng và SLO.
- Khôi phục riêng một cửa hàng không còn là khôi phục một database: phải trích
  các dòng của cửa hàng đó từ một bản khôi phục tạm.
- Không có code đa cửa hàng ở stage-4; ADR này chỉ quyết cách lưu.

Đội xem lại khi một cửa hàng quá lớn so với bảng chung, hoặc phải được khôi
phục riêng. Cửa hàng đó chuyển sang database riêng; các cửa hàng khác vẫn ở
bảng chung.

### Ý kiến đã nhận

Tester hỏi làm sao biết row-level security thật sự chặn. Mỗi bảng có policy sẽ
có một test chạy truy vấn không có bộ lọc dưới role của service và chỉ thấy
dòng của cửa hàng đã đặt; việc này nằm trong release 3 của kế hoạch triển
khai.

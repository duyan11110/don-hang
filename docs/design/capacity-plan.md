# Thiết kế: kế hoạch dung lượng cho 1.000 cửa hàng

Trạng thái: kế hoạch ở stage-4. Ước lượng tải lúc đỉnh từ các yếu tố nghiệp
vụ, rồi so với giới hạn của từng tài nguyên dùng chung. Mọi con số đầu vào là
giả định, ghi rõ ở từng chỗ; thời gian đo trên lab không phải số của
production.

### Tải dự kiến

Từ `docs/team/multi-shop-requirements.md`:

| Đầu vào | Giá trị |
|---|---|
| Số cửa hàng | 1.000 |
| Đơn mỗi cửa hàng mỗi ngày | Trung bình 50 (giả định) |
| Ngày đông nhất so với ngày thường | Gấp 2 (giả định) |
| Phần đơn của ngày rơi vào giờ đông nhất | 12% (giả định) |
| Lần đọc sản phẩm cho mỗi đơn đặt được, kể cả lượt xem không mua | 40 (giả định) |

| Kết quả | Trung bình ngày thường | Giờ đông nhất của ngày đông nhất |
|---|---|---|
| Đơn mỗi ngày | 50.000 | 100.000 |
| Đơn mỗi giây | khoảng 0,6 | khoảng 3,3 (12.000 đơn trong một giờ) |
| Đọc sản phẩm mỗi giây | khoảng 23 | khoảng 133 |

Kế hoạch tính theo giờ đông nhất, không theo trung bình ngày: trung bình ngày
thấp hơn đỉnh hơn năm lần, và hệ thống hỏng vào giờ đông, không vào lúc trung
bình.

### Giới hạn đã biết

- `catalog-reads` trong `DonHang.Api/Program.cs`: mỗi process chạy tối đa 20
  lần đọc sản phẩm cùng lúc và xếp hàng thêm 5; vượt nữa trả `503`. Stage-4
  giữ nguyên giới hạn này.
- Trần đọc của một process, theo định luật Little: số đang chạy = thông lượng
  × thời gian trung bình, nên thông lượng tối đa = 20 / thời gian một lần đọc.
  Thời gian trung bình một lần đọc danh sách sản phẩm khi 20 chỗ đã đầy, đo
  bằng `scripts/backend/load-steps.sh` trên lab: khoảng 10–12 ms (số lab,
  giả định cho tới khi đo trên môi trường giống production). Trần mỗi process
  khoảng 20 / 0,012, tức khoảng 1.600 lần đọc mỗi giây.
- 2 Pod api (`deploy/gitops/config-repo-kustomize/base/api.yaml`): trần của
  cả hai khoảng 3.200 lần đọc mỗi giây.
- Mọi lệnh ghi và mọi lần đọc đều vào primary PostgreSQL.
- Kết nối database: mỗi Pod api giữ một pool kết nối của Npgsql cho
  `ConnectionStrings:Default`, kích thước mặc định vì connection string không
  đặt. Payments, Notifications, các migration và job backup mở kết nối tới
  cùng server. Tổng số Pod × kết nối tối đa mỗi Pod của mọi service phải nhỏ
  hơn `max_connections` của PostgreSQL; đọc giá trị đó bằng
  `SHOW max_connections`, không đoán.

### Khoảng dư

Quy tắc: tải đỉnh không vượt một nửa trần của 2 Pod api, để một Pod gánh được
toàn bộ khi mất Pod kia (node hỏng, rolling update).

- Đọc sản phẩm: đỉnh khoảng 133 mỗi giây, một nửa trần khoảng 1.600. Đạt.
- Đặt đơn: đỉnh khoảng 3,3 đơn mỗi giây, mỗi đơn một transaction ngắn trên
  primary. Đạt, không phải tài nguyên chặn.

### Tài nguyên hết trước

Trần `catalog-reads` tính theo thời gian một lần đọc. Khi Redis dừng hay
database chậm, mỗi lần đọc lâu hơn và trần tụt theo: nếu một lần đọc mất 200
ms, trần mỗi process còn 100 mỗi giây, một nửa trần của 2 Pod còn 100, thấp
hơn đỉnh 133. Vì vậy `catalog-reads` hết trước, trả `503` cho đọc sản phẩm,
trong khi đặt đơn vẫn chạy.

Bước làm trước khi tới đó, theo thứ tự:

1. Thêm Pod api; mỗi Pod thêm 20 chỗ đọc nhưng cũng thêm một pool kết nối,
   nên số Pod bị chặn bởi `max_connections`.
2. Chuyển danh sách sản phẩm sang replica (mục dưới), khi đỉnh đọc sản phẩm
   vượt khoảng dư của primary.

### Khi nào lập lại kế hoạch

- Số cửa hàng hay số đơn trung bình mỗi cửa hàng lệch quá một phần tư so với
  bảng trên.
- Một cửa hàng giữ hơn 10% tổng số đơn của ngày đông nhất.
- `Program.cs` đổi giới hạn, `api.yaml` đổi số Pod, hay thời gian một lần đọc
  đo trên staging khác xa số của lab.

### Đọc từ replica

Ở stage-4 API chỉ có một connection string, `ConnectionStrings:Default`; mọi
lần đọc vào primary. `db-replica` chỉ dùng trong lab.

- Chuyển trước nếu cần: danh sách sản phẩm. `consistency-per-operation.md`
  cho phép nó trả dữ liệu hơi cũ.
- Không chuyển: đơn của chính khách, `GET /api/v1/orders/{id}/history`, mọi
  lần đọc ngay sau một lần ghi của cùng người gọi, vì replica có thể chưa có
  lần ghi đó.
- Điều kiện kích hoạt: đỉnh dự kiến của đọc sản phẩm vượt khoảng dư của
  primary.
- Đường lui: mỗi lần đọc qua replica phải quay về primary khi replica trễ hơn
  mức danh sách sản phẩm chịu được, hoặc không trả lời.

Replica chỉ gánh những lần đọc được chuyển sang nó; mọi lệnh ghi và mọi lần
đọc phải ở primary vẫn nằm trên primary. Stage-4 không có code định tuyến.

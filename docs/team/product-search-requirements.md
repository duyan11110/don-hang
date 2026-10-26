# Yêu cầu: tìm sản phẩm trong một cửa hàng

Bước 1 của `docs/design/system-design-method.md` cho bài toán tìm sản phẩm.
Bản nháp của product owner và đội Đơn Hàng. Mọi con số ghi "giả định" là giả
định của đội, chưa phải số đo. Thiết kế trả lời ở
`docs/design/product-search-design-review.md`.

### Xuất phát

- `GET /api/v1/products` trả từng trang, mặc định 20, tối đa 100 sản phẩm, sắp
  theo `id`, chỉ lọc được theo `maxPriceVnd` (`ProductsController`,
  `CatalogService.ListAsync`).
- Khách muốn tìm một sản phẩm theo tên phải lật hết các trang.
- `ProductCache` chỉ giữ từng sản phẩm theo `id` trong Redis; danh sách sản phẩm
  đọc thẳng `CatalogDbContext`, không qua cache.

### Phạm vi

"Tìm kiếm" có hai nghĩa, tách riêng ở đây:

- Trong phạm vi: khách tìm một sản phẩm bên trong một cửa hàng, trên app và web.
- Ngoài phạm vi: trang sản phẩm công khai để máy tìm kiếm tìm thấy từ bên ngoài.
  ADR 0017 để việc đó cho một quyết định riêng; tài liệu này không quyết lại.

### Kịch bản

| Số | Tình huống | Phản hồi | Đo |
|---|---|---|---|
| TK-1 | Khách gõ tên không dấu, ví dụ `ban phim` | Ra sản phẩm có tên có dấu, `Bàn phím cơ` trong `db/seed.sql` | Mọi tên có dấu tìm được bằng chữ không dấu |
| TK-2 | Khách gõ vài từ | Sản phẩm khớp nhất lên trước | Sản phẩm chứa đủ mọi từ đứng trước sản phẩm chỉ chứa một phần |
| TK-3 | Khách của cửa hàng A tìm | Chỉ sản phẩm của cửa hàng A | Không kết quả nào của cửa hàng khác |
| TK-4 | Nhân viên thêm hay đổi tên sản phẩm | Kết quả tìm thấy sản phẩm mới, tên mới | Trong vài phút (giả định) |
| TK-5 | Giờ đông, nhiều người tìm cùng lúc | Đặt đơn vẫn trả lời như ngày thường | Tìm kiếm không lấy sức chứa của đặt đơn |

TK-4 là cùng lựa chọn mà danh sách sản phẩm đã có trong
`consistency-per-operation.md`: được phép hơi cũ.

### Ước lượng

- Sản phẩm mỗi cửa hàng: nhiều nhất vài nghìn (giả định 5.000), trung bình vài
  trăm (giả định 200); cả 1.000 cửa hàng khoảng 200.000 dòng. PostgreSQL chứa
  thoải mái.
- Lần tìm: 20% số lần đọc sản phẩm (giả định); với đỉnh khoảng 133 lần đọc mỗi
  giây của `capacity-plan.md`, khoảng 27 lần tìm mỗi giây.
- Rủi ro là tải, không phải dữ liệu: mỗi lần tìm là một truy vấn, vì
  `ProductCache` chỉ giữ sản phẩm theo `id`.

### Giả định và người xác nhận

| Giả định | Người xác nhận (vai trò) |
|---|---|
| Nhiều nhất 5.000 sản phẩm mỗi cửa hàng | Product owner, từ hợp đồng đã ký |
| Sản phẩm mới tìm được sau vài phút là đủ | Product owner |
| Tìm chiếm 20% số lần đọc sản phẩm | Đội Cửa hàng (ADR 0025, giả định), đo sau khi có |
| Đội Cửa hàng phụ trách Catalog và tìm kiếm | Trưởng nhóm |

### Driver xếp hạng

1. Chữ gõ không dấu tìm ra sản phẩm (TK-1).
2. Tìm kiếm không bao giờ lấy sức chứa mà đặt đơn cần (TK-5).
3. Kết quả chỉ trong cửa hàng của người gọi (TK-3).

# 0030. Tìm sản phẩm bằng full-text search của PostgreSQL, trong Catalog

Trạng thái: Đã chấp nhận
Ngày: đề xuất đầu Sprint 26, quyết định cuối tuần đầu Sprint 26
Người quyết định: trưởng nhóm
Hạn góp ý: hết thứ Sáu tuần đầu Sprint 26

Chưa xây ở stage-4: `ICatalog.ListAsync` vẫn chỉ lọc theo `maxPriceVnd`. Thiết
kế và buổi review ở `docs/design/product-search-design-review.md`.

### Bối cảnh

`docs/team/product-search-requirements.md`: gõ không dấu vẫn ra sản phẩm, khớp
nhất lên trước, chỉ trong cửa hàng của người gọi, sản phẩm mới tìm được sau vài
phút (giả định), không lấy sức chứa của đặt đơn. Nhiều nhất vài nghìn sản phẩm
mỗi cửa hàng (giả định); bảng `products` chỉ có `id`, `name`, `price_vnd`.

### Các phương án

- `LIKE '%...%'` trên `name`: không thêm gì. Một index B-tree thường không phục
  vụ được mẫu bắt đầu bằng wildcard, nên mỗi lần tìm đọc mọi dòng; không sắp
  theo mức khớp, không bỏ dấu.
- Full-text search của PostgreSQL trong Catalog: từ tìm được dựng từ chính dòng
  sản phẩm, có inverted index, không bản sao nào phải giữ cho khớp.
- Một công cụ tìm kiếm riêng, chạy như một service khác: khớp phong phú hơn
  (gõ sai, đồng nghĩa) và sức chứa riêng. Nhưng nó là một bản sao của sản phẩm,
  nuôi từ thay đổi của Catalog qua outbox, nên trễ sau `products`, cần cách
  dựng lại, và thêm một service phải chạy.

### Quyết định

Chọn full-text search của PostgreSQL, trong Catalog, chủ của `products`.

- Từ tìm được dựng từ tên sản phẩm trên chính dòng đó: chữ thường, bỏ dấu bằng
  extension `unaccent` đi kèm PostgreSQL, rồi tách từ bằng một cấu hình không
  cắt đuôi từ, vì PostgreSQL không có cấu hình tìm kiếm cho tiếng Việt.
- Câu tìm được chuẩn hóa đúng cùng cách.
- Một inverted index trên từ tìm được; mỗi lần tìm chỉ đọc dòng khớp.
- Tìm là một tham số tùy chọn của danh sách sản phẩm qua `ICatalog`, dưới cùng
  giới hạn `catalog-reads`; giới hạn theo cửa hàng của người gọi; sắp theo mức
  khớp rồi theo `id`.

### Hệ quả

- Không bản sao mới: đổi tên sản phẩm là đổi luôn từ tìm được trong cùng dòng.
- Tìm kiếm dùng chung database với đặt đơn; tải được giữ bởi `catalog-reads`,
  trần theo cửa hàng của ADR 0016, và chuyển sang replica khi
  `capacity-plan.md` cho phép.
- Không tìm ra từ gõ sai, không biết từ đồng nghĩa.
- Cửa hàng chuyển database theo ADR 0026 mang theo từ tìm được của nó.

Đội xem lại quyết định khi: khiếu nại về gõ sai hay từ đồng nghĩa vượt 5% số
phản hồi về tìm kiếm trong một tháng (giả định); tải tìm kiếm vượt khoảng dư cả
khi đã chuyển sang replica.

### Ý kiến đã nhận

Product owner hỏi sao không dùng luôn một công cụ tìm kiếm cho chắc. Ước lượng
cho thấy vài nghìn sản phẩm mỗi cửa hàng; công cụ riêng thêm một bản sao và một
service mà driver chưa đòi. Điều kiện xem lại ghi khi nào đòi. Quyết định không
đổi.

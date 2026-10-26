# Checklist review thiết kế backend

Trạng thái: dùng từ stage-4 khi review một thay đổi thiết kế backend (pull
request có ADR hay tài liệu thiết kế, hoặc thay đổi chạm tới ranh giới, dữ
liệu, giới hạn). Mỗi câu hỏi trỏ tới tài liệu hay ADR giữ câu trả lời mong
đợi, để người review so thay đổi với một quyết định đã có, không với sở thích.
Câu nào đã có phép kiểm tự động thì trỏ tới phép kiểm đó thay vì hỏi lại;
danh sách đầy đủ các phép kiểm theo thuộc tính chất lượng ở
`fitness-functions.md`.

### Cách dùng

Chỉ đi qua những nhóm thay đổi chạm tới. Thay đổi nhỏ trong một module có thể
chỉ cần một nhóm; thay đổi một ranh giới tin cậy hay một giới hạn tải cần
nhiều nhóm. Câu trả lời "không biết" là một kết quả: ghi nó thành câu hỏi mở
trong pull request.

### Chủ dữ liệu và nhất quán

| Câu hỏi | Câu trả lời ở |
|---|---|
| Thay đổi có thêm bản sao của một dữ liệu không? Bản sao đó cập nhật thế nào, và khi lệch thì tin ai? | `data-ownership.md` |
| Có hai nơi cùng ghi một dữ liệu không? | `data-ownership.md`, mục hai nơi cùng muốn sửa |
| Thao tác bị đổi chọn gì khi không tới được nguồn, và khi bình thường? Lựa chọn mới có khớp lý do nghiệp vụ không? | `consistency-per-operation.md` |
| Code có dùng kiểu bên trong của module khác, hay tham chiếu project mà ranh giới không cho không? | Phép kiểm: `ModuleBoundaryTests`, `DependencyRuleTests` |
| Service có kết nối tới database của service khác không? Không phép kiểm nào thấy điều này | `data-ownership.md` |

### Thay đổi schema và message

| Câu hỏi | Câu trả lời ở |
|---|---|
| Migration có chạy được khi Pod của phiên bản trước còn phục vụ không (expand rồi contract)? | ADR 0008, `multi-shop-data-rollout.md` |
| Migration có giữ khóa lâu trên bảng lớn không? Index có tạo `CONCURRENTLY`, có `lock_timeout` không? | `multi-shop-data-rollout.md` |
| Message đổi hình dạng thế nào? Thuộc tính mới có tùy chọn cho tới khi không còn message cũ không? | Phép kiểm: `OrderMessageContractTests` |

### Bảo mật

| Câu hỏi | Câu trả lời ở |
|---|---|
| Thay đổi có thêm hay đổi một ranh giới tin cậy không? Threat model đã có dòng cho nó chưa? | `threat-model.md` |
| Service mới dùng credential nào? Nó đọc được gì ngoài dữ liệu của mình? | `threat-model.md`, P1, P2 |
| Dữ liệu cá nhân mới lấy từ đâu, đã xác minh chưa? | ADR 0014 |
| Có khóa ký hay secret mới nằm trong service không? | ADR 0015 |
| Hành động mới có cần ghi vào nhật ký kiểm toán không? | `audit-log.md` |
| Package và image có lỗ hổng đã biết không? | Phép kiểm: restore `--locked-mode` và bước quét Grype trong CI |

### Resilience

| Câu hỏi | Câu trả lời ở |
|---|---|
| Lời gọi mới ra ngoài process có timeout, thử lại có giới hạn không? | `refund-design.md` (cách Payments gọi cổng) |
| Endpoint mới có cần giới hạn tải không, theo khách hay theo số đồng thời? | `Program.cs`; phép kiểm: `RateLimitTests` |
| Service phụ thuộc mới dừng thì thao tác nào còn chạy? | `consistency-per-operation.md` |

### SLO và dung lượng

| Câu hỏi | Câu trả lời ở |
|---|---|
| Thay đổi có chạm tới một SLI không? Request mới có được đếm đúng (tốt, xấu) không? | `slo.md` |
| Thay đổi có tiêu error budget đã hết không? | `slo.md`, mục Chính sách |
| Tải đỉnh mới có còn dưới một nửa trần của 2 Pod không? Số kết nối có còn dưới `max_connections` không? | `capacity-plan.md` |

### Cô lập giữa cửa hàng

| Câu hỏi | Câu trả lời ở |
|---|---|
| Bảng mới có chứa dữ liệu của một cửa hàng không? Nó có `shop_id` không? | ADR 0013, `multi-shop-data-rollout.md` |
| Truy vấn mới có lọc theo cửa hàng lấy từ access token không? | ADR 0013 |
| Một cửa hàng đông có dùng hết tài nguyên chung mới không? | ADR 0016 |

### Ví dụ: đọc danh sách sản phẩm từ `db-replica`

Đề xuất: thêm connection string tới replica, chuyển `GET /api/v1/products`
sang đó để giảm tải cho primary.

- Nhất quán: `consistency-per-operation.md` cho phép danh sách sản phẩm trả
  dữ liệu hơi cũ, và danh sách không ghi lại gì từ kết quả đọc. Đạt. Một sản
  phẩm đọc qua `ProductCache` không được chuyển: nạp cache từ replica có thể
  đặt giá cũ trở lại.
- Dung lượng: `capacity-plan.md` đặt điều kiện kích hoạt, đỉnh đọc sản phẩm
  vượt khoảng dư của primary. Pull request phải cho thấy điều kiện đó đã tới,
  hoặc ghi lý do làm sớm. Connection string mới là một pool kết nối nữa trong
  mỗi Pod api: tính lại tổng với `max_connections`.
- SLO: S3 trong `slo.md` vẫn đo ở API, nên lỗi của replica hiện ra trong S3.
  Cần đường lui về primary khi replica trễ quá mức hay không trả lời, nếu không
  một replica hỏng tiêu budget của S3.
- Chủ dữ liệu: Catalog vẫn là chủ của `products`; replica là bản sao mới, phải
  thêm vào `data-ownership.md` cùng cách nó cập nhật (replication không đồng
  bộ) và tin ai khi lệch (primary).

Kết luận mẫu: chấp nhận khi điều kiện kích hoạt đã tới, có đường lui, và
`data-ownership.md` được sửa trong cùng pull request.

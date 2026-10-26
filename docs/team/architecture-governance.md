# Governance kiến trúc của Đơn Hàng

Tài liệu này ghi ai quyết định gì về kiến trúc, quyết định được ghi ở đâu, và
luật nào được giữ bằng phép kiểm thay vì bằng người duyệt. Đội không có bước
duyệt kiến trúc riêng cho từng thay đổi: phần lớn thay đổi chỉ cần review pull
request như thường, phần còn lại cần một ADR theo `docs/adr/README.md`.

### Nguyên tắc kiến trúc

Mỗi nguyên tắc là một luật ngắn, rút từ các quyết định đã có, kèm lý do và điều
nó kéo theo. Muốn làm khác một nguyên tắc thì theo mục Ngoại lệ.

| Số | Nguyên tắc | Lý do | Hệ quả | Nguồn |
|---|---|---|---|---|
| NT1 | Mỗi service sở hữu dữ liệu của mình; không service nào đọc hay ghi bảng của service khác | Dữ liệu có đúng một chủ thì khi các bản sao lệch nhau, biết tin ai | Cần dữ liệu của service khác thì hỏi qua lời gọi hoặc message, hoặc giữ một bản sao có cách cập nhật nói rõ | `docs/design/data-ownership.md`, ADR 0002, 0003 |
| NT2 | Service nói chuyện với nhau qua message có hợp đồng được test, không qua một project chung chứa domain | Một project domain dùng chung buộc các service deploy cùng nhau mỗi khi nó đổi | Mỗi service giữ bản sao hình dạng message của mình; `OrderMessageContractTests` hỏng ngay trong pull request đổi một bên mà không đổi bên kia | `DonHang.Tests/Messaging/OrderMessageContractTests.cs` |
| NT3 | Mọi cửa hàng được phục vụ từ một bản triển khai; cô lập giữa cửa hàng nằm trong dữ liệu | Mở cửa hàng và cấu hình cửa hàng không cần deploy, chi phí vận hành không nhân theo số cửa hàng | Mỗi request, mỗi dòng dữ liệu và mỗi message phải biết nó thuộc cửa hàng nào | ADR 0012, 0013 |
| NT4 | Mọi thay đổi production đi qua repo cấu hình, theo chiến lược phát hành của thành phần đó | Một bản phát hành hỏng chạm tới mọi cửa hàng cùng lúc, nên thay đổi phải có dấu vết và quay lại được | Không sửa tay trên cluster production; api phát hành bằng canary, Notifications và Payments bằng rolling update | ADR 0019 |
| NT5 | Không thêm lớp trừu tượng cho một nhu cầu chưa có | Lớp thêm vào có giá trả ngay ở mỗi lần đọc và sửa code, còn nhu cầu có thể không bao giờ tới | Đề xuất một lớp như vậy cần chỉ ra nhu cầu đang có, không phải nhu cầu có thể có | ADR 0011 |

### Ai quyết định gì

| Loại quyết định | Ví dụ | Ai quyết (vai trò) | Cần ADR? | Phải hỏi ai |
|---|---|---|---|---|
| Thay đổi bên trong một module hay một service, không đổi hợp đồng | Đổi cách Catalog đọc cache, tách một lớp trong Payments | Người làm, qua review pull request như thường | Không | Người review pull request |
| Đổi hợp đồng của API công khai hoặc của một message | Bỏ một field của `POST /api/v1/orders`, đổi tên một thuộc tính của `OrderMessage` | Trưởng nhóm, sau thời gian góp ý | Có | Người phụ trách mỗi bên đọc hợp đồng đó (app, service nhận message) |
| Đổi dữ liệu của cửa hàng, quyền, khóa hoặc trust boundary | Thêm `shop_id` vào một bảng, thêm role ở Keycloak, đổi nơi giữ khóa ký | Trưởng nhóm | Có, đối chiếu `docs/design/threat-model.md` | Lập trình viên phụ trách nền tảng, product owner nếu cửa hàng thấy được |
| Thêm một thành phần tự chạy, một vendor hoặc một dịch vụ trả phí | Dịch vụ gửi email (ADR 0024) | Trưởng nhóm, cùng product owner | Có, kèm một lần đánh giá như `payment-gateway-evaluation.md` | Product owner |
| Làm khác một nguyên tắc ở trên | Một service đọc thẳng bảng của service khác trong một thời gian | Trưởng nhóm | Có: ADR ghi ngoại lệ và thời điểm xem lại | Người phụ trách phần bị ảnh hưởng |

### Phép kiểm thay cho duyệt

Luật nào máy kiểm được thì để máy kiểm, trên mọi thay đổi, không chờ một người
duyệt từng lần:

- Các phép kiểm tự động trong `fitness-functions.md`.
- `docs/design/backend-review-checklist.md` khi review thiết kế backend.
- `docs/design/cluster-review-checklist.md` khi review thay đổi tới cluster.

Đội không có hội đồng duyệt kiến trúc riêng: quyết định cần ADR đi theo quy
trình trong `docs/adr/README.md`. Khi có nhiều đội, bảng "Ai quyết định gì"
được xem lại, vì "người phụ trách bên đọc" khi đó có thể là một đội khác.

### Ngoại lệ

Mỗi ngoại lệ là một ADR ghi nguyên tắc bị làm khác, lý do và hạn xem lại, và
được liệt kê ở đây để luật và ngoại lệ của nó cùng nhìn thấy.

| ADR | Nguyên tắc | Ngoại lệ | Hạn xem lại |
|---|---|---|---|
| (chưa có ngoại lệ nào) | | | |

### Giả định cần theo dõi

Mỗi ADR dưới đây đúng khi một giả định còn đúng. Tín hiệu mở lại chép từ mục
điều kiện xem lại của chính ADR đó, không thêm. Khi một tín hiệu xuất hiện,
người theo dõi đề xuất một ADR mới; ADR cũ không được viết lại.

| ADR | Giả định | Tín hiệu mở lại | Thấy tín hiệu ở đâu | Người theo dõi (vai trò) |
|---|---|---|---|---|
| 0012 | Mọi cửa hàng dùng chung một bản triển khai | Một cửa hàng có hợp đồng đòi một bản hệ thống riêng | Hợp đồng với cửa hàng trước khi ký | Product owner |
| 0012 | Một đội sửa được mọi module mà không phải chờ ai | Số đội tăng tới mức các đội phải chờ nhau để sửa cùng một module | Sprint planning, pull request bị chặn vì chờ đội khác | Trưởng nhóm |
| 0019 | Mọi cửa hàng dùng chung một bản triển khai | Một cửa hàng cần một bản triển khai riêng (mở lại cả ADR 0012) | Hợp đồng với cửa hàng trước khi ký | Product owner |
| 0019 | Bản cũ và bản mới luôn chạy cùng lúc được | Một thay đổi không thể làm tương thích với bản trước, nên bản cũ và bản mới không chạy cùng lúc được | Review thiết kế, mục thay đổi schema và message của `backend-review-checklist.md` | Lập trình viên backend |
| 0019 | Notifications và Payments nhận việc chủ yếu qua queue | Notifications hoặc Payments bắt đầu nhận phần lớn việc qua Gateway | HTTPRoute mới trỏ tới hai service đó | Lập trình viên phụ trách nền tảng |
| 0020 | Không hợp đồng nào đòi phục hồi nhanh hơn số đo của DR drill | Một hợp đồng hoặc SLA đòi RTO hoặc RPO thấp hơn số đo của DR drill | Hợp đồng với cửa hàng trước khi ký; số đo của mỗi lần DR drill | Product owner |
| 0020 | Dữ liệu cửa hàng được nằm ở bất kỳ region nào | Dữ liệu của một số cửa hàng phải nằm ở một vùng xác định | Hợp đồng với cửa hàng trước khi ký | Product owner |
| 0021 | Không yêu cầu nào đòi mã hóa trong cluster | Một hợp đồng đòi mã hóa lời gọi bên trong cluster | Hợp đồng với cửa hàng, danh sách yêu cầu như `compliance-controls.md` | Product owner |
| 0021 | Một nhóm, ba service .NET | Service đến từ nhiều nhóm hoặc nhiều ngôn ngữ, nên mỗi codebase tự làm mutual TLS, retry và số đo theo lời gọi trở nên đắt hơn một mesh | Service mới đề xuất bằng ADR, đội mới thành lập | Trưởng nhóm |
| 0021 | Service chỉ gọi nhau trong một cluster | Service bắt đầu gọi nhau giữa các cluster | ADR hoặc thay đổi cluster qua `cluster-review-checklist.md` | Lập trình viên phụ trách nền tảng |
| 0022 | Không khách nào đòi nơi chạy riêng | Hợp đồng của một khách đòi máy riêng hoặc dữ liệu ở một nơi xác định | Hợp đồng với cửa hàng trước khi ký | Product owner |
| 0022 | Managed rẻ hơn tự chạy cluster | Phí của nhà cung cấp vượt chi phí giả định của việc đội tự chạy cluster (cột A của bảng) | Hóa đơn hằng tháng của nhà cung cấp | Trưởng nhóm |
| 0024 | Dịch vụ A đưa email tới hộp thư khách | Tỉ lệ email tới hộp thư khách thấp hơn mức giả định trong `email-service-evaluation.md` | Báo cáo gửi của Dịch vụ A | Lập trình viên backend |
| 0024 | Giá của Dịch vụ A nằm trong TCO đã tính | Giá của A vượt TCO giả định trong `email-service-evaluation.md` | Hóa đơn của Dịch vụ A | Trưởng nhóm |
| 0024 | Dịch vụ A nhận email qua SMTP | A ngừng nhận email qua SMTP | Thông báo thay đổi API của Dịch vụ A | Lập trình viên backend |

### Xem lại

Mỗi quý, cùng `technical-strategy.md` và `roadmap.md`: thêm ADR mới có điều
kiện mở lại vào bảng trên, xem tín hiệu nào đã xuất hiện, và xem bảng "Ai
quyết định gì" còn đúng với số đội hiện có không.

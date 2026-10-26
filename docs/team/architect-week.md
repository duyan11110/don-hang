# Một tuần của vai trò kiến trúc sư ở Đơn Hàng

Tài liệu ghi lại một tuần giả định của vai trò kiến trúc sư ở Đơn Hàng: làm gì,
với ai, và mỗi việc để lại gì cho người khác đọc. Vai trò này làm việc với cả
ba đội của ADR 0025 (Đặt hàng, Cửa hàng, platform) và không thuộc riêng đội nào
(giả định). Tài liệu không quyết ai giữ vai trò, không ghi tên người, và không
nói về chức danh hay lương.

Mọi việc dưới đây đã có cách làm riêng trong repo (design review, ADR, review
pull request, postmortem, kèm người, brief lãnh đạo). Tài liệu chỉ cho thấy
chúng nằm cạnh nhau trong một tuần thế nào.

### Lịch trong tuần

Tuần giả định sau khi ADR 0025 được chấp nhận: đội platform và đội Đặt hàng đã
làm việc theo `team-structure.md`, đội Cửa hàng mới được lập.

| Ngày | Hoạt động | Với ai (vai trò) | Đầu ra | Cách làm ở |
|---|---|---|---|---|
| Thứ Hai | Đọc trước tài liệu review thiết kế chat hỗ trợ, ghi câu hỏi trước buổi review | Một mình | Danh sách câu hỏi gửi người đề xuất trước buổi review | `docs/design/design-review-template.md`, `docs/design/support-chat-design-review.md` |
| Thứ Hai | Góp ý pull request của một ADR ở trạng thái `Đề xuất`, trong thời gian góp ý (giả định: trần kết nối chat theo cửa hàng, rủi ro đầu tiên của `support-chat-design-review.md`) | Đội Đặt hàng | Ý kiến trong pull request; ý kiến làm đổi quyết định vào mục "Ý kiến đã nhận" của ADR | `docs/adr/README.md`, mục Quy trình |
| Thứ Ba | Dự buổi review thiết kế chat hỗ trợ | Đội Đặt hàng, đội platform, product owner | Mỗi câu hỏi chưa trả lời được thành một dòng trong mục "Rủi ro và câu hỏi mở", có người trả lời theo vai trò và hạn | `docs/design/design-review-template.md` |
| Thứ Ba | Review pull request của đội Cửa hàng đổi cách Catalog đọc cache | Đội Cửa hàng | Nhận xét review trỏ tới câu hỏi của checklist, không tới sở thích | `docs/design/backend-review-checklist.md`, mục Chủ dữ liệu và nhất quán |
| Thứ Ba | Review pull request đổi số replica của api trong repo cấu hình | Đội platform | Nhận xét review; câu "không biết" ghi thành câu hỏi mở trong pull request | `docs/design/cluster-review-checklist.md` |
| Thứ Tư | Đọc postmortem 0001, kiểm action item đã có chỗ trong kế hoạch | Một mình, rồi trưởng nhóm | Ghi chú cho buổi roadmap: action item "chọn thành phần gửi thông báo cho alert" chưa có mục trong `roadmap.md` | `docs/postmortems/0001-doc-san-pham-tra-503.md`, `docs/team/roadmap.md` |
| Thứ Tư | Xem roadmap với product owner | Product owner, trưởng nhóm | Thứ tự của mục "Tiếp theo" giữ hay đổi; mục đổi tầm ghi vào bảng "Đã dời" kèm lý do (giả định: tuần này không mục nào đổi tầm) | `docs/team/roadmap.md`, `docs/team/technical-strategy.md` |
| Thứ Năm | Buổi 1-1 kèm một lập trình viên mới | Lập trình viên mới | Việc tiếp theo được chọn cùng nhau | `docs/team/mentoring-plan.md`, `docs/team/architecture-skills-checklist.md` |
| Thứ Năm | Ghép cặp viết một phép kiểm cho một quy tắc (giả định: api từ chối khởi động khi `RateLimiting:CatalogReads` nhỏ hơn mức tối thiểu, action item của postmortem 0001) | Lập trình viên backend | Một pull request nhỏ có test; khi merge, phép kiểm thành một dòng của bảng "Phép kiểm đang có" trong `fitness-functions.md` | `docs/design/fitness-functions.md` |
| Thứ Sáu | Trình lãnh đạo bản cập nhật của brief đội platform | Lãnh đạo, trưởng nhóm | Quyết định được hỏi, nêu ở câu đầu (giả định: thêm người thứ tư cho đội platform, vì yêu cầu gửi sang đội này thường quá 2 ngày làm việc mới được trả lời), và câu trả lời ghi vào brief | `docs/team/leadership-brief-platform-team.md`, mục Điều chưa chắc |
| Thứ Sáu | Trả lời các yêu cầu gửi tới vai trò trong tuần | Các đội | Mỗi câu trả lời trỏ tới quy tắc, checklist hay ADR (mục dưới) | `docs/team/architecture-governance.md`, mục Ai quyết định gì |

Người nghe đổi theo ngày: với lập trình viên, vai trò nói lý do đằng sau một
quy tắc; với product owner, nói đánh đổi bằng kết quả cửa hàng thấy được; với
lãnh đạo, nói quyết định cần họ đưa ra trước, rồi mới tới lý do.

Mỗi hoạt động kết thúc bằng một thứ được ghi lại: một ý kiến trong pull
request, một dòng câu hỏi mở có người trả lời, một ghi chú cho roadmap. Một
quyết định chỉ nói trong buổi họp thì người đến sau không tìm thấy, và phải
hỏi lại.

### Thời gian theo loại việc

Khoảng giờ trong một tuần 40 giờ, là giả định của dự án cho một nhóm cỡ Đơn
Hàng, không phải số liệu ngành.

| Loại việc | Giờ trong tuần (giả định) | Gồm |
|---|---|---|
| Review và tài liệu | 16 tới 20 | Đọc trước tài liệu review, góp ý ADR, review pull request, đọc postmortem, sửa brief |
| Trao đổi | 10 tới 14 | Buổi review thiết kế, buổi roadmap, trình lãnh đạo, trả lời yêu cầu của các đội |
| Kèm người | 3 tới 5 | Buổi 1-1, nhận xét review có giải thích lý do |
| Code | 3 tới 5 | Ghép cặp viết phép kiểm cho một quy tắc |

Phần code nhỏ nhưng không bằng không: nó giữ cho vai trò biết một quyết định
tốn bao nhiêu công khi đội phải làm theo, và nó dành cho việc kiểm một quyết
định (như một phép kiểm), không cho tính năng.

### Yêu cầu chuyển lại cho đội

Các yêu cầu gửi tới vai trò trong tuần (giả định). Mỗi câu trả lời trỏ tới chỗ
đã giữ câu trả lời, theo bảng "Ai quyết định gì" của
`architecture-governance.md`, để lần sau đội tự tìm được.

| Yêu cầu | Thuộc quyền quyết định của ai | Câu trả lời |
|---|---|---|
| Đội Cửa hàng hỏi có cần ADR khi đổi cách Catalog đọc cache không | Người làm, qua review pull request: thay đổi bên trong một module, không đổi hợp đồng `ICatalog` | Không cần ADR. Trỏ dòng đầu của bảng "Ai quyết định gì" và mục Chủ dữ liệu và nhất quán của `backend-review-checklist.md` |
| Đội Đặt hàng chọn một thư viện bên trong Payments khác với thư viện vai trò kiến trúc sư sẽ chọn | Người làm, qua review pull request: thay đổi bên trong một service | Giữ lựa chọn của đội. Mối lo ghi thành một nhận xét trong pull request; đội là bên trả chi phí của lựa chọn đó |
| Một lập trình viên đề nghị thêm service mesh cho staging | Trưởng nhóm, bằng một ADR mới thay ADR 0021, nếu điều kiện mở lại đã xuất hiện | Chưa làm. Ba điều kiện mở lại của ADR 0021 chưa điều kiện nào xuất hiện (bảng "Giả định cần theo dõi" của `architecture-governance.md`), và "Không dùng service mesh" nằm trong mục Không làm của `technical-strategy.md` |
| Đội Cửa hàng đề nghị chọn ngay một công cụ tìm kiếm riêng, trước khi cần | Trưởng nhóm, bằng một ADR mới thay ADR 0030 | Để mở. ADR 0030 ghi lúc nào cần xem lại: khiếu nại về gõ sai hay từ đồng nghĩa vượt 5% số phản hồi về tìm kiếm trong một tháng (giả định), hoặc tải tìm kiếm vượt khoảng dư cả khi đã chuyển sang replica. Chưa tín hiệu nào xuất hiện |
| Đội Cửa hàng muốn thêm một role ở Keycloak cho nhân viên cửa hàng | Trưởng nhóm, có ADR, đối chiếu `docs/design/threat-model.md` | Không phải việc vai trò kiến trúc sư quyết một mình. Trỏ dòng thứ ba của bảng "Ai quyết định gì"; vai trò góp ý khi ADR được đề xuất |

Câu hỏi gửi tới vai trò ít đi qua từng quý là dấu hiệu checklist, mẫu và
golden path đang làm được việc của chúng.

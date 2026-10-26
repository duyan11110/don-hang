# Fitness function của Đơn Hàng

Fitness function là một phép kiểm tự động cho thấy hệ thống vẫn còn một thuộc
tính chất lượng phải giữ, chạy theo mỗi thay đổi thay vì nhờ trí nhớ của người
review. Tài liệu này ghi, ở stage-4, mỗi thuộc tính Đơn Hàng phải giữ, ADR hay
yêu cầu sinh ra nó, phép kiểm đang giữ nó và phép kiểm chạy khi nào; rồi ghi
những thuộc tính chưa phép kiểm tự động nào giữ, kèm lựa chọn của đội cho từng
cái. Các checklist review (`backend-review-checklist.md`,
`cluster-review-checklist.md`) trỏ về đây thay vì hỏi lại điều máy đã kiểm.

### Phép kiểm đang có

Các job nhắc dưới đây ở `.github/workflows/ci.yml`.

| Thuộc tính chất lượng | Nguồn | Phép kiểm | Chạy ở đâu, khi nào |
|---|---|---|---|
| Lõi Ordering không phụ thuộc lớp ngoài: không biết database, RabbitMQ hay Catalog | Quy tắc phụ thuộc của `DonHang.Domain` | `DonHang.Tests/Architecture/DependencyRuleTests.cs` | Job `test`, mỗi push và pull request |
| Catalog không dùng project nào của Ordering, và chỉ công khai hợp đồng `ICatalog` | Hợp đồng module `DonHang.Catalog/ICatalog.cs` | `DonHang.Tests/Architecture/ModuleBoundaryTests.cs`: `CatalogUsesNoOrderingProject`, `CatalogMakesPublicOnlyItsContract` | Job `test`, mỗi push và pull request |
| Notifications và Payments không dùng project nào của Đơn Hàng ngoài `DonHang.Messaging` | ADR 0002, 0003; nguyên tắc NT2 của `docs/team/architecture-governance.md` | `ModuleBoundaryTests`: `ServiceUsesNoDonHangProjectButMessaging`, `MessagingUsesNoDonHangProject` | Job `test`, mỗi push và pull request |
| Message của api đọc được ở cả Notifications và Payments, kể cả message cũ còn trong queue | Nguyên tắc NT2 | `DonHang.Tests/Messaging/OrderMessageContractTests.cs` | Job `test`, mỗi push và pull request |
| Câu trả lời của api vẫn có mọi field app đọc, cùng kiểu JSON | ADR 0018 (app gọi thẳng api) | Hai phía của mẫu trong `contracts/app/`: `DonHang.Tests/Integration/AppContractTests.cs` hỏi api thật; `DonHang.App/test/api_contract_test.dart` đọc mẫu bằng `fromJson` của app | `AppContractTests` ở job `test`, `api_contract_test.dart` ở job `app`; mỗi push và pull request |
| Feature của app chỉ dùng nhau qua file công khai, theo một chiều | `docs/design/app-structure.md` | `DonHang.App/test/architecture/feature_boundaries_test.dart` | Job `app`, mỗi push và pull request |
| Màu của app chỉ đến từ thương hiệu, nên mỗi cửa hàng đổi được thương hiệu | CH-4 của `docs/team/multi-shop-requirements.md` | `DonHang.App/test/design/no_raw_colors_test.dart` | Job `app`, mỗi push và pull request |
| Một khách vượt giới hạn đặt đơn không chặn khách khác | Giới hạn `orders` trong `DonHang.Api/Program.cs` | `DonHang.Tests/Integration/RateLimitTests.cs` | Job `test`, mỗi push và pull request |
| Gói phụ thuộc không đổi ngoài ý muốn | Lock file của .NET và của app | `dotnet restore --locked-mode` (job `test`), `flutter pub get --enforce-lockfile` (job `app`) | Mỗi push và pull request |
| Image không mang lỗ hổng High hay Critical đã có bản sửa | TT-5 của `docs/team/compliance-controls.md` | Bước quét Grype của job `image` (`scripts/devops/scan-image.sh` trên SBOM của mỗi image); `.grype.yaml` ghi từng ngoại lệ được chấp nhận kèm lý do | Lúc build image: mỗi push và pull request |
| Manifest và overlay là object Kubernetes hợp lệ | `cluster-review-checklist.md`; overlay theo ADR 0007 | Các bước kubeconform của job `manifests` (manifest, môi trường của repo cấu hình, mỗi overlay Kustomize, platform giám sát) và `helm lint` cho chart | Mỗi push và pull request |
| Alert burn rate bật và tắt đúng lúc | `docs/design/alerts.md` | `scripts/devops/alert-rules-test.sh`, một bước của job `manifests`: `promtool check rules` rồi `promtool test rules slo.test.yml` | Mỗi push và pull request |
| Cấu hình OpenTofu đúng định dạng và hợp lệ | `deploy/tofu/` | Job `iac`: `tofu fmt -check`, rồi validate từng cấu hình | Mỗi push và pull request |
| Pod chỉ chạy image của Đơn Hàng ghi bằng digest | `cluster-review-checklist.md`; `platform/policies/require-image-digest.yaml` của repo cấu hình | Admission policy `require-image-digest` | Mỗi lần một Pod được tạo trong cluster |

"Mỗi push" là push lên mọi nhánh trừ nhánh của Dependabot: pull request của
Dependabot đã chạy cùng các job.

### Lúc chạy quyết định phép kiểm thấy gì

Mọi phép kiểm ở trên chạy khi có thay đổi: một push, một pull request, hay một
Pod mới. Không phép kiểm nào chạy theo lịch. Điều đổi bên ngoài code thì không
phép kiểm nào thấy cho tới thay đổi kế tiếp, như một lỗ hổng được công bố sau
khi image đã build và đang chạy.

Một phép kiểm chỉ thấy điều nó nói: `ModuleBoundaryTests` đọc tham chiếu giữa
các assembly, nên một service nối thẳng vào database của service khác vẫn qua
(mục dưới).

### Theo dõi liên tục

Ngoài các phép kiểm theo thay đổi, Prometheus của staging tính S1–S4 của
`slo.md` bằng recording rule và bật alert burn rate theo `alerts.md`. Đó là
theo dõi hệ thống đang chạy, không phải phép kiểm chặn một thay đổi; production
chưa có Prometheus (`slo.md`, mục Chưa có).

### Chưa có phép kiểm tự động

Mỗi dòng ghi một lựa chọn: thêm phép kiểm, theo dõi, hoặc chấp nhận kèm lý do.
Ghi ra để khoảng trống được biết, không bị tưởng là đã có phép kiểm.

| Thuộc tính | Nguồn | Vì sao chưa có | Lựa chọn |
|---|---|---|---|
| Yêu cầu hoàn tiền được trả lời trong 2 giây | YC-7 của `docs/team/refund-requirements.md` | Thiết kế giữ nó (api trả `202` mà không gọi cổng thanh toán), nhưng không phép kiểm nào đo 2 giây theo mỗi thay đổi | Theo dõi bằng S4 trong `slo.md` và alert `RefundRequestsFastBurn`, `RefundRequestsSlowBurn` trên staging |
| Image đang chạy không mang lỗ hổng công bố sau khi build | TT-5 của `docs/team/compliance-controls.md` | Grype chỉ quét lúc build; không có lần quét theo lịch. Dependabot mở pull request mỗi tuần, nhưng chỉ khi có bản mới của một phụ thuộc | Chấp nhận tới khi có production: lab và staging không giữ dữ liệu khách thật. Xem lại khi production nhận khách |
| Mỗi service chỉ đọc và ghi database của mình | Nguyên tắc NT1, `data-ownership.md` | `ModuleBoundaryTests` không thấy kết nối database | Chấp nhận kèm lý do: `backend-review-checklist.md` hỏi câu này ở mỗi review; role riêng cho từng service (mục "Sau đó" của `docs/team/roadmap.md`) sẽ chặn ở database |
| Một cửa hàng không đọc được dữ liệu cửa hàng khác | CH-1; ADR 0013 | Chưa có code đa cửa hàng ở stage-4 | Thêm phép kiểm khi xây row-level security (release 3 của `multi-shop-data-rollout.md`): một truy vấn quên lọc cửa hàng vẫn không thấy dòng của cửa hàng khác |
| Một cửa hàng đông không làm cửa hàng khác bị từ chối | CH-3; ADR 0016; `multi-shop-architecture-review.md` | Giới hạn theo cửa hàng chưa xây: `Program.cs` giữ giới hạn chung | Thêm phép kiểm khi xây, như `RateLimitTests` nhưng theo cửa hàng |
| Trải nghiệm trên máy khách: phiên không lỗi, thời gian tới màn hình đầu tiên, đơn kẹt trong hàng đợi offline | A1–A3 của `app-experience.md` | App chưa gửi số đo nào | Theo dõi bằng dashboard khi app gửi số đo (`app-experience.md`, mục Khoảng trống) |
| Thuộc tính của ADR 0026–0033 (database riêng cho cửa hàng lớn, thông báo nhiều kênh, đối soát hoàn tiền, ký bảng kê, tìm sản phẩm, báo cáo, chat hỗ trợ, cửa hàng tự đăng ký) | ADR 0026–0033 | Các ADR này chưa xây ở stage-4, nên chưa có gì để kiểm | Thêm phép kiểm cùng lúc xây: mỗi ADR khi được xây thêm phép kiểm cho thuộc tính nó giữ, hoặc thêm một dòng ở đây kèm lựa chọn |

### Khi nào sửa danh sách

- Khi thêm, đổi hay bỏ một phép kiểm hoặc một job trong `ci.yml`.
- Khi một ADR mới đặt ra một thuộc tính phải giữ, hoặc khi một ADR ở bảng
  trên được xây.
- Mỗi quý, cùng lần xem lại `docs/team/architecture-governance.md`: dòng nào ở
  mục "Chưa có" đã đổi lựa chọn.

Một phép kiểm tốn công giữ hơn rủi ro nó che thì không đáng tự động hóa. Lựa
chọn đó cũng ghi ở mục "Chưa có", để không bị đọc là bỏ sót.

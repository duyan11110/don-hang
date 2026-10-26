# 0025. Tổ chức hai đội theo luồng và một đội platform

Trạng thái: Đã chấp nhận
Ngày: đề xuất giữa Sprint 23, quyết định cuối Sprint 23
Người quyết định: trưởng nhóm, cùng product owner
Hạn góp ý: hết thứ Sáu tuần thứ hai Sprint 23

Không đổi code ở stage-4. Đội hôm nay, kế hoạch chi tiết và cách các đội làm
việc với nhau ở `docs/team/team-structure.md`; ADR này không chép lại.

### Bối cảnh

Đơn Hàng sẽ phục vụ 1.000 cửa hàng (`docs/team/multi-shop-requirements.md`),
và `docs/team/roadmap.md` xếp sau đó các kết quả cần nhiều việc hơn một đội
làm được: mở cửa hàng không cần deploy, production trên Kubernetes managed,
giám sát production. `multi-shop-requirements.md` giả định ba tới bốn đội khi
đủ 1.000 cửa hàng.

Hôm nay một đội bảy người (một product owner, một scrum master, bốn lập trình
viên, một tester, như `docs/team/sprint-example.md`) sở hữu mọi thứ: api với
hai module Ordering và Catalog, Notifications, Payments, DonHang.App, platform
của staging (`docs/team/platform-capabilities.md`), CI, và trực cho tất cả
(`docs/team/on-call.md`). Vài phần chỉ một người sửa được, như lớp cluster của
OpenTofu. Câu hỏi là thêm người theo cách nào.

### Các phương án

- Phương án A, một đội lớn hơn: thêm người vào đội hiện có. Không phải vẽ ranh
  giới nào, nhưng số cặp người có thể cần trao đổi tăng theo n(n-1)/2: bảy
  người là 21 cặp, mười bốn người là 91. Mỗi người vẫn phải biết gần như mọi
  thứ đội sở hữu, nên tải nhận thức của từng người không giảm.
- Phương án B, đội theo tầng: một đội frontend (DonHang.App), một đội backend
  (api, Notifications, Payments), một đội vận hành (cluster, CI, trực). Mỗi đội
  sâu trong một kỹ năng, nhưng gần như mọi thay đổi một cửa hàng thấy được đi
  qua cả ba: một màn hình mới, endpoint của nó, rồi deploy và alert của nó.
- Phương án C, hai đội theo luồng cộng một đội platform:
  - Đội Đặt hàng: module Ordering (`DonHang.Domain`, `DonHang.Infrastructure`,
    controller đơn của api), Payments, Notifications, `DonHang.App/lib/features/ordering`.
  - Đội Cửa hàng: module Catalog (`DonHang.Catalog`), việc mở cửa hàng mới theo
    `docs/design/multi-shop-data-rollout.md`, `DonHang.App/lib/features/catalog`
    và `lib/features/auth`.
  - Đội platform: OpenTofu, Argo CD và repo cấu hình, Gateway, Sealed Secrets,
    Prometheus, admission policy, `templates/dotnet-service` và golden path,
    vận hành PostgreSQL, RabbitMQ và Keycloak.

  Mỗi đội theo luồng làm một thay đổi từ ý tưởng tới production mà không chờ
  đội khác; đội platform giữ phần chung để hai đội kia không phải hiểu cluster
  tới tận cùng. Cái giá: phải vẽ ranh giới, và phần nằm giữa hai đội cần chủ
  rõ ràng.

### Quyết định

Chọn phương án C. Ranh giới đội đi theo ranh giới module và service đã có, nên
mỗi đội sở hữu những phần hệ thống đổi cùng nhau; giữa hai đội theo luồng chỉ
có hợp đồng module `ICatalog`.

Từ chối A vì số cặp trao đổi và vì tải nhận thức của mỗi người không giảm. Từ
chối B vì gần như mọi thay đổi cửa hàng thấy được cần cả ba đội, nên mỗi thay
đổi chờ ở hai chỗ giao việc.

Phần dùng chung: `DonHang.App/lib/design/` và `lib/shared/` do đội Đặt hàng
giữ, đội Cửa hàng gửi pull request; `Program.cs` của api cũng vậy. Keycloak do
đội platform vận hành, còn phần đăng nhập trong app (`lib/features/auth`) thuộc
đội Cửa hàng.

### Hệ quả

- Đội platform được lập trước đội theo luồng thứ hai: đội hiện có trở thành
  đội Đặt hàng, rồi đội Cửa hàng lập sau. Lý do và chi phí ở
  `docs/team/leadership-brief-platform-team.md`.
- Vòng trực tách theo đội khi đội mới thành lập: mỗi đội theo luồng trực cho
  service của mình, đội platform trực cho cluster và công cụ chung. Tới lúc đó
  `on-call.md` giữ một vòng trực chung.
- Chưa có đội hệ con phức tạp: ký hóa đơn trong HSM của nhà cung cấp (ADR
  0023) chưa có code chạy với HSM đó, nên là ứng viên đầu tiên khi được xây.
- Ranh giới module trở thành ranh giới đội, nên đổi ranh giới module về sau là
  đổi cả cách tổ chức đội.

Điều kiện mở lại:

- Hai đội cùng phải sửa một module trong phần lớn thay đổi của một quý: ranh
  giới đội, hoặc ranh giới module, đang đặt sai chỗ.
- Ký hóa đơn của ADR 0023 được xây: xem lại có cần đội hệ con phức tạp không.

### Ý kiến đã nhận

Tester hỏi đội theo tầng có giữ được kiểm thử tập trung hơn không. Câu trả
lời: mỗi đội theo luồng có tester của mình, và các phép kiểm chung nằm ở CI
(`docs/design/fitness-functions.md`), không ở một đội. Quyết định không đổi.

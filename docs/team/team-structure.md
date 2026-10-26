# Cấu trúc đội của Đơn Hàng

Tài liệu ghi đội hôm nay sở hữu những gì, vì sao không lớn lên bằng cách thêm
người vào một đội, và kế hoạch theo ADR 0025 khi Đơn Hàng phục vụ 1.000 cửa
hàng (`multi-shop-requirements.md`). Số người, số ngày và số sprint ở đây là
giả định của dự án, không phải chuẩn chung.

### Đội hôm nay

Một đội: một product owner, một scrum master, bốn lập trình viên, một tester
(như `sprint-example.md`). Đội sở hữu toàn bộ hệ thống ở stage-4:

| Phần | Gồm | Người giữ | Số người sửa được |
|---|---|---|---|
| api | Module Ordering (`DonHang.Domain`, `DonHang.Infrastructure`) và Catalog (`DonHang.Catalog`) trong `DonHang.Api` | Lập trình viên backend | 4 |
| Notifications | `DonHang.Notifications`, database `donhang_notifications` | Lập trình viên backend | 3 |
| Payments | `DonHang.Payments`, database `donhang_payments`, cổng thanh toán (ADR 0010) | Lập trình viên backend | 2 |
| DonHang.App | App Flutter (`docs/design/app-structure.md`) | Lập trình viên frontend | 2 |
| Platform của staging | Các năng lực trong `platform-capabilities.md`: Argo CD, Gateway, Sealed Secrets, Prometheus, admission policy, golden path | Trưởng nhóm, lập trình viên phụ trách nền tảng | 2 |
| Lớp cluster và lớp platform của OpenTofu | `deploy/tofu/` | Trưởng nhóm | 1: chỉ một người sửa được |
| CI | `.github/workflows/ci.yml`, các job `image` và `publish` | Lập trình viên backend | 2 |
| Trực | Một vòng trực cho mọi thứ ở trên (`on-call.md`) | Bốn lập trình viên | 4 |

Cột cuối đếm người đã từng sửa phần đó và tự sửa được không cần hỏi ai (giả
định của đội). Phần chỉ một người sửa được là rủi ro: người đó nghỉ thì phần
đó đứng.

### Vì sao không thêm người vào một đội

Trong một nhóm n người có n(n-1)/2 cặp có thể cần trao đổi với nhau. Bảy người
là 21 cặp; cùng đội đó lên mười bốn người là 91 cặp. Thêm người cũng không làm
mỗi người phải biết ít đi: mỗi người vẫn review và trực cho gần như mọi thứ đội
sở hữu, nên tải nhận thức của từng người giữ nguyên hoặc tăng.

Tải cũng giảm được mà không thêm người: sở hữu ít thứ hơn, hoặc làm cho mỗi
thứ dễ dùng hơn, như golden path làm cho việc thêm một service
(`golden-path.md`).

### Kế hoạch

Theo ADR 0025, Đơn Hàng lớn lên bằng cách thêm đội nhỏ, mỗi đội sở hữu trọn
những phần hệ thống đổi cùng nhau:

| Đội | Kiểu | Sở hữu |
|---|---|---|
| Đặt hàng | Theo luồng | Module Ordering, Payments, Notifications, `DonHang.App/lib/features/ordering`, `lib/design/`, `lib/shared/` |
| Cửa hàng | Theo luồng | Module Catalog, việc mở cửa hàng mới (`docs/design/multi-shop-data-rollout.md`), `lib/features/catalog`, `lib/features/auth` |
| Platform | Platform | OpenTofu, Argo CD và repo cấu hình, Gateway, Sealed Secrets, Prometheus, admission policy, golden path, vận hành PostgreSQL, RabbitMQ và Keycloak |

- Mỗi đội 5 tới 7 người (giả định). Cỡ đội đặt theo lượng mỗi đội phải biết
  để sửa và vận hành phần của mình, không theo số service hay số dòng code.
- Đội platform lập trước đội theo luồng thứ hai: đội hôm nay trở thành đội
  Đặt hàng.
- Ranh giới đội đi theo ranh giới module và service đã có. Ranh giới đội về
  sau sẽ định hình ranh giới hệ thống, nên kế hoạch không vẽ ranh giới mới cắt
  ngang một module.
- Chưa có đội hệ con phức tạp. Ký hóa đơn trong HSM của nhà cung cấp (ADR
  0023) chưa có code chạy với HSM đó; khi được xây, đó là ứng viên đầu tiên.

### Cách các đội làm việc với nhau

| Cặp đội | Cách | Tới khi nào |
|---|---|---|
| Platform và Đặt hàng | Cộng tác: làm chung trong lúc chuyển sang cluster managed (`docs/design/cluster-migration-plan.md`) | Tới khi chuyển xong; sau đó X-as-a-service qua golden path |
| Platform và Cửa hàng | X-as-a-service qua golden path và các năng lực trong `platform-capabilities.md`; một người của đội platform hỗ trợ học (facilitating) về SLO, alert và runbook | Hỗ trợ học trong 2 sprint đầu của đội Cửa hàng (giả định), rồi chỉ còn X-as-a-service |
| Đặt hàng và Cửa hàng | X-as-a-service qua hợp đồng module `ICatalog` (`DonHang.Catalog/ICatalog.cs`): đội Cửa hàng đổi gì phía sau `ICatalog` cũng được, không cần hỏi, miễn `ICatalog` giữ hình dạng | Lâu dài |

Cộng tác tìm ra ranh giới tốt nhanh nhưng tốn sự chú ý của cả hai đội, nên
luôn có hạn. Hai đội phải cộng tác trên gần như mọi thay đổi là dấu hiệu ranh
giới đặt sai chỗ: đó là câu hỏi thiết kế, đưa vào điều kiện mở lại của ADR
0025, không phải chuyện trao đổi chưa tốt.

### Mỗi đội cung cấp gì

| Đội | Cung cấp | Cách gửi yêu cầu | Trả lời trong |
|---|---|---|---|
| Platform | Cluster, golden path, Argo CD, Gateway, Sealed Secrets, Prometheus, sao lưu database | Issue có nhãn của đội platform; thay đổi nhỏ thì gửi thẳng pull request | 2 ngày làm việc (giả định) |
| Đặt hàng | Đặt đơn, hoàn tiền, email cho khách; message `OrderMessage`; `lib/design/` và `lib/shared/` của app | Issue có nhãn của đội Đặt hàng | 2 ngày làm việc (giả định) |
| Cửa hàng | `ICatalog`, mở cửa hàng mới, đăng nhập trong app | Issue có nhãn của đội Cửa hàng | 2 ngày làm việc (giả định) |

"Trả lời" là nói sẽ làm, khi nào, hoặc vì sao không; không phải làm xong. Nhờ
vậy một yêu cầu sang đội khác là một bước đã biết, không phải một lần thương
lượng.

### Ai vận hành gì

- Mỗi đội theo luồng giữ SLO, alert, runbook và trực cho service của mình
  (`docs/design/slo.md`, `docs/design/alerts.md`, `docs/runbooks/`). Người viết
  service cũng deploy, theo dõi và trả lời cho nó ở production; không có đội
  riêng nhận deploy và theo dõi service của đội khác.
- Đội platform vận hành và trực cho cluster và công cụ chung. Nhờ đội platform
  giữ phần chung, các đội theo luồng deploy qua golden path thay vì mỗi đội tự
  học cluster tới tận cùng.
- Tới khi đội mới thành lập, một đội vẫn làm và vận hành mọi thứ, nên
  `on-call.md` có một vòng trực chung. Tổ chức vòng trực cho bền ở
  `on-call-staffing.md`.

### Khi nào xem lại

- Mỗi khi một đội mới thành lập.
- Khi hai đội cùng phải sửa một module trong phần lớn thay đổi của một quý
  (điều kiện mở lại của ADR 0025).
- Khi một yêu cầu sang đội khác thường xuyên quá 2 ngày làm việc mới được trả
  lời.
- Khi một phần trong bảng "Đội hôm nay" vẫn chỉ một người sửa được sau hai
  quý.

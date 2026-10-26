# Sổ nợ kỹ thuật của Đơn Hàng

Sổ này ghi những món nợ kỹ thuật đội biết mình đang mang: hình dạng của code
hay cấu hình làm mỗi lần sửa vùng đó tốn công hơn. Khác sổ rủi ro
(`risk-register-example.md`): rủi ro có thể không bao giờ xảy ra, còn món nợ
ở đây đã có sẵn và đang tính lãi mỗi lần sửa. Lỗi (code chạy sai) không ghi
vào đây; lỗi được sửa như lỗi.

Lãi ghi bằng lời của đội, như người đọc bị hiểu nhầm điều gì hay mỗi lần sửa
phải làm thêm việc gì, không bằng điểm số. Cột "Quyết định" là một trong bốn:
trả ngay, trả cùng lần sửa tới vùng đó, chấp nhận (tiếp tục trả lãi, biết rõ
vì sao), xóa sổ (vùng đó sắp bỏ).

### Nợ đang mang

| Số | Món nợ | Ở đâu | Từ đâu ra | Lãi mỗi lần sửa | Trả bằng cách nào | Quyết định | Người theo dõi |
|---|---|---|---|---|---|---|---|
| N2 | Bảng `payments` cũ còn trong database `donhang` | `donhang`, `PostgresFixture` | Phát hiện sau: còn lại khi Payments có database riêng (ADR 0003) | Người đọc tưởng API còn giữ dòng tiền; kế toán hỏi nên đối soát với bảng nào | Migration xóa bảng như N1, sau khi kế toán xác nhận (ADR 0008, bước 3); dump đã có từ bước 1, khoảng 1 ngày | Trả khi kế toán xác nhận | Lập trình viên backend |
| N3 | `POST /api/v1/orders` vẫn nhận `unitPriceVnd` của từng dòng nhưng bỏ qua, giá lấy từ Catalog | `DonHang.Api/Dtos.cs`, `OrdersController.cs` | Có chủ ý: giữ để client cũ không hỏng | Người đọc API tưởng mình đặt được giá; mỗi lần sửa DTO phải nhớ field này không làm gì | Bỏ field ở một phiên bản API mới, sau khi client cũ ngừng gửi nó | Chấp nhận: còn client cũ dùng `/api/v1`, bỏ field là thay đổi phá vỡ; xem lại khi `/api/v1` có ngày ngừng | Lập trình viên backend |
| N4 | App ghi cứng `localhost` cho địa chỉ API và Keycloak | `DonHang.App/lib/shared/api_client.dart`, `lib/features/auth/keycloak_sign_in.dart` | Có chủ ý: app chỉ chạy trên máy dev | Chạy app ở bất kỳ địa chỉ nào khác phải sửa code và build lại; app chưa đưa được lên cluster | Đọc địa chỉ từ cấu hình lúc build, khoảng 2–3 ngày | Trả cùng lần sửa tới: khi app được đưa lên cluster | Lập trình viên frontend |

### Ước lượng lãi và gốc

Từ stage-4, mỗi món đang mang có thêm ước lượng bằng giờ, để việc trả nợ được
lập kế hoạch và cân như một story. Mọi số dưới đây là giả định của đội, ghi
thành khoảng thấp–cao vì đó là ước lượng, không phải số đo. Số lần sửa mỗi quý
là ước tính của đội; `scripts/management/change-hotspots.sh` chỉ là một nguồn,
vì lịch sử repo phần lớn là commit dựng bài. Sổ không quy giờ ra tiền; đội nào
muốn thì nhân với chi phí giờ của mình.

Lãi mỗi quý = số lần sửa vùng đó mỗi quý × giờ thêm mỗi lần. Trả nợ có lời khi
lãi cộng lại trong thời gian vùng đó còn được sửa lớn hơn gốc; vùng sắp bỏ thì
để nguyên rẻ hơn.

| Số | Lần sửa mỗi quý | Giờ thêm mỗi lần | Lãi mỗi quý | Gốc | Vùng còn được sửa | Kết luận |
|---|---|---|---|---|---|---|
| N2 | 2–4: mỗi lần chạm database `donhang`, `PostgresFixture` hay truy vấn tiền, và mỗi câu hỏi của kế toán | 1–3 giờ: giải thích bảng nào là thật, kiểm lại truy vấn như `db/queries/revenue-by-customer.sql` còn đọc bảng cũ | 2–12 giờ | 6–10 giờ: migration xóa bảng (dump đã có), bỏ bảng khỏi `PostgresFixture`, chuyển hoặc bỏ truy vấn còn đọc bảng cũ | Ít nhất 4 quý: đối soát (ADR 0028) và báo cáo (ADR 0031) đều sẽ chạm câu hỏi "tiền nằm ở bảng nào" | Trả có lời: 4 quý lãi 8–48 giờ, hơn gốc. Trả ngay khi kế toán xác nhận |
| N3 | 2–3: mỗi lần sửa DTO hay controller đơn | 0,25–0,5 giờ: nhớ field không làm gì, giải thích trong review | 0,5–1,5 giờ | 40–80 giờ: một phiên bản API mới không nhận `unitPriceVnd` (request của `/api/v2/orders` cũng mang field này), chuyển app sang, chờ và theo dõi tới khi client cũ ngừng gọi, rồi ngừng phiên bản cũ | Nhiều năm: đặt đơn là phần sửa nhiều nhất | Chấp nhận: 8 quý lãi 4–12 giờ, vẫn dưới gốc. Xem lại khi `/api/v1` có ngày ngừng, vì khi đó gốc gần như chỉ còn phần sửa code |
| N4 | 1–2: mỗi lần cần chạy app ở địa chỉ khác `localhost` | 1–2 giờ: sửa địa chỉ trong code, build lại, nhớ hoàn tác | 1–4 giờ | 16–24 giờ (2–3 ngày): đọc địa chỉ từ cấu hình lúc build | Lâu dài, nhưng lãi tăng mạnh từ khi app chạy trên cluster: mỗi lần build cho môi trường nào cũng phải sửa | Hôm nay chưa có lời: 4 quý lãi 4–16 giờ, chưa tới gốc. Trả cùng lần đưa app lên cluster, như quyết định ở trên |

N1 không có trong bảng: đã trả (mục dưới).

### Nợ đã trả

| Số | Món nợ | Từ đâu ra | Trả bằng gì |
|---|---|---|---|
| T1 | Repo cấu hình chép đầy đủ manifest cho mỗi môi trường (`envs/staging`, `envs/production`), nên thay đổi chung phải sửa hai lần | Có chủ ý (ADR 0005) | Chuyển sang overlay Kustomize (ADR 0007) trong một commit, `scripts/k8s/kustomize-config-repo.sh`; kiểm bằng chỗ khác Argo CD báo: chỉ ConfigMap và Deployment của api |
| T2 | `QueuedNotifier` lưu job email cùng transaction với đơn qua chung một DbContext; hợp với một process, thành việc phải gỡ khi Notifications ra service riêng | Phát hiện sau | Outbox: API ghi message vào `outbox_messages` cùng transaction, relay gửi lên RabbitMQ, Notifications nhận qua inbox; `QueuedNotifier` và `INotifier` bị xóa |
| N1 | Bảng `notifications` cũ còn trong database `donhang` | Phát hiện sau: còn lại khi Notifications có database riêng (ADR 0002) | ADR 0008, bước 1–2: dump bảng cũ bằng `pg_dump -Fc --table` vào volume `backups` (`scripts/backend/drop-old-notifications.sh`), rồi migration `20261101090000_DropOldNotificationsTable` xóa bảng, cùng commit bỏ bảng khỏi lệnh `TRUNCATE` của `PostgresFixture` |

### Cách đội dùng sổ này

- Sổ được xem lại cùng nhịp với sổ rủi ro, ở mỗi sprint planning: thêm món mới,
  xem lại quyết định của từng món.
- Món nào nằm trong file đội sửa thường xuyên thì lãi trả thường xuyên nhất:
  `scripts/management/change-hotspots.sh` đếm số commit đã sửa từng file.
- Thời gian trả nợ hiện trong kế hoạch, thành story riêng hoặc một phần sprint
  nói rõ, không giấu vào ước lượng của việc khác.
- Món đã trả chuyển sang bảng "Nợ đã trả", kèm việc trả đã tốn những gì.

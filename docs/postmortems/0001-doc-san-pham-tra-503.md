# Postmortem 0001: đọc sản phẩm trả 503 sau một thay đổi cấu hình của api

Trạng thái: đã xem lại, còn action item mở
Mức: SEV2
Người viết: người trực của tuần (vai trò người chỉ huy sự cố)
Ngày xem lại cùng đội: hai ngày làm việc sau sự cố

Sự cố này là sự cố mà `scripts/devops/incident-drill.sh` tái hiện trên staging.
Postmortem viết như cho một sự cố thật để đội luyện cách viết; mọi số liệu không
có trong output của script được ghi là giả định.

### Tóm tắt

Một commit vào `envs/staging` của repo cấu hình đặt giới hạn `catalog-reads`
của api còn một lượt đọc cùng lúc, không ai chờ. Đọc sản phẩm bắt đầu trả `503`
cho mọi lượt đọc trùng nhau. Alert `ProductReadsFastBurn` bật, người trực revert
commit đó theo bước 1 của runbook, và alert hết khi tỉ lệ lỗi 5 phút xuống dưới
ngưỡng.

### Ảnh hưởng

- Khách mở danh sách sản phẩm thì một phần lượt mở báo lỗi; đặt đơn không bị
  ảnh hưởng trực tiếp, nhưng khách không xem được sản phẩm thì không đặt.
- Thời gian: từ commit tới khi alert hết khoảng 9 phút (giả định, theo lần diễn
  tập); khách gặp lỗi từ lúc Pod api mới nhận request tới lúc Pod của bản revert
  thay xong chúng.
- Error budget: tỉ lệ đọc sản phẩm lỗi trong 1 giờ vẫn trên 6,72% khi alert hết
  (output của script). Với lượng đọc giả định 500.000 lượt trong 28 ngày, budget
  của S3 là 2.500 lượt lỗi; sự cố này tiêu khoảng 900 lượt (giả định), hơn một
  phần tư budget, nên postmortem là bắt buộc theo `docs/design/slo.md`.

### Dòng thời gian

Mốc tính từ commit gây sự cố. Thứ tự lấy từ output của `incident-drill.sh`; số
phút là giả định, theo lần diễn tập.

| Mốc | Điều xảy ra |
|---|---|
| T+0 | Commit "api: catalog-reads one read at a time, none waiting" vào `envs/staging`; Argo CD áp, các Pod api được thay |
| T+1,5 phút | Tỉ lệ đọc lỗi 1 giờ và 5 phút đều trên 6,72%: `ProductReadsFastBurn` pending |
| T+3,5 phút | Alert giữ đủ 2 phút: firing; người trực xác nhận, đặt SEV2 |
| T+4 phút | Runbook bước 1: `git log -- envs/staging` cho thấy commit ở T+0; người trực revert commit đó |
| T+5 phút | Pod api của bản revert thay xong; lỗi `503` dừng (vài `502`/`504` trong lúc thay Pod) |
| T+9 phút | Tỉ lệ 5 phút xuống dưới ngưỡng: alert hết, trong khi tỉ lệ 1 giờ vẫn trên ngưỡng |
| T+40 phút | SLI giữ tốt 30 phút: người chỉ huy tuyên bố kết thúc |

### Yếu tố góp phần

- Thay đổi cấu hình đi thẳng vào Deployment `api` của `envs/staging`, không qua
  bước canary mà ADR 0019 yêu cầu cho api. Canary ở bước 10% đã dừng thay đổi
  này với chỉ một phần mười request bị ảnh hưởng, như `canary-steps.sh --bad`
  cho thấy. Quy trình hiện coi "chỉ đổi cấu hình" là không cần canary; quy tắc
  đó chưa được viết ra ở đâu, nên người làm có lý do hợp lý để nghĩ vậy.
- Không phép kiểm nào chặn một giá trị giới hạn bất thường. `PermitLimit=1` là
  giá trị hợp lệ về kiểu, kubeconform và admission policy đều nhận, và review
  pull request không có danh sách giá trị cần xem kỹ.
- Giới hạn `catalog-reads` đọc từ cấu hình mà không có giá trị tối thiểu, nên
  một số nhỏ tới mức làm hỏng dịch vụ vẫn được nhận khi khởi động.

### Điều đã giúp

- Alert hai cửa sổ: bật trong vài phút sau khi lỗi bắt đầu, và hết vài phút sau
  revert nhờ cửa sổ 5 phút, không phải chờ cả giờ.
- Thay đổi là một commit, nên giảm thiểu là một `git revert`; người trực không
  phải hiểu nguyên nhân trước khi giảm thiểu.
- Runbook `docs/runbooks/product-reads-burn.md` đã được chạy thử trong diễn tập,
  nên bước 1 đúng ngay lần đầu.

### Điều làm chậm

- Revert thay lại mọi Pod api, nên lỗi kéo dài thêm trong lúc rollout, kèm vài
  `502`/`504` khi Gateway không thấy Pod nào sẵn sàng.
- Chưa có thành phần gửi thông báo (`docs/team/on-call.md`): ngoài diễn tập,
  alert chỉ được thấy khi có người hỏi Prometheus.

### Action item

| Việc | Loại | Người phụ trách | Hạn | Trạng thái |
|---|---|---|---|---|
| Ghi vào `canary-checks.md` rằng thay đổi cấu hình của api cũng đi qua canary | ngăn | Trưởng nhóm | Cuối sprint hiện tại | mở |
| Thêm giá trị tối thiểu cho `RateLimiting:CatalogReads` khi api khởi động (từ chối khởi động nếu quá nhỏ) | ngăn | Lập trình viên backend | Sprint sau | mở |
| Thêm vào danh sách review pull request của repo cấu hình: mọi thay đổi giới hạn, timeout, số replica | phát hiện | Trưởng nhóm | Cuối sprint hiện tại | mở |
| Chọn thành phần gửi thông báo cho alert (`on-call.md`, mục Khoảng trống) | phát hiện | Lập trình viên phụ trách nền tảng | Hai sprint tới | mở |

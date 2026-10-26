# Roadmap của Đơn Hàng

Lập ở Sprint 23 (giả định), xếp theo ba tầm: bây giờ, tiếp theo, sau đó. Mỗi
mục là một kết quả cửa hàng hay đội thấy được, không phải một tính năng có
ngày cố định, và mỗi mục ghi hành động của `technical-strategy.md` mà nó phục
vụ. Mục không phục vụ hành động nào thì bị hỏi lại trước khi được xếp vào.

Chỉ mục "Bây giờ" có dự báo. Càng xa thì càng ít biết, nên "Tiếp theo" chỉ có
thứ tự và "Sau đó" không có ngày.

### Bây giờ

| Kết quả | Hành động phục vụ | Dự báo |
|---|---|---|
| Mọi dòng dữ liệu mang `shop_id`, code cũ vẫn chạy (release 1 của `multi-shop-data-rollout.md`) | H1 | 2 tới 3 sprint |
| Mất máy chạy database không còn là mất bản sao lưu: base backup và WAL có bản ở region thứ hai | H4 | 3 tới 4 sprint, trong phần cố định bên dưới |

Cách tính dự báo: velocity của bốn sprint đủ người trong `velocity-history.md`
là 8 tới 11 điểm; bốn phần năm số đó (6,4 tới 8,8 điểm) dành cho các mục của
roadmap, phần còn lại là phần cố định bên dưới. Release 1 ước lượng 13 điểm
(giả định): 13 / 8,8 ≈ 1,5 → 2 sprint và 13 / 6,4 ≈ 2,03 → 3 sprint. Sao lưu
sang region thứ hai ước lượng 5 điểm (giả định), làm bằng phần cố định 1,6 tới
2,2 điểm mỗi sprint: 3 tới 4 sprint. Dự báo được tính lại ở mỗi sprint
planning với velocity mới nhất.

### Tiếp theo

| Kết quả | Hành động phục vụ |
|---|---|
| Mở cửa hàng mới không cần deploy: code biết cửa hàng của mỗi request (release 2) | H1 |
| Production chạy trên Kubernetes managed | H2 |
| Đội biết production đang khỏe: SLO đo được ở production, có alert khi error budget bị tiêu nhanh | H3 |
| Khách nhận email thật từ production qua Dịch vụ A (ADR 0024) | H5 |
| Không thay đổi production nào lên mà chỉ một người làm và tự duyệt | H6 |

### Sau đó

| Kết quả | Hành động phục vụ |
|---|---|
| Một cửa hàng không đọc được dữ liệu cửa hàng khác kể cả khi code quên lọc: row-level security và role riêng cho từng service (release 3) | H1 |
| Truy được ai đã làm gì với đơn và hoàn tiền: nhật ký kiểm toán theo `audit-log.md` | H6 |
| Quyền truy cập được rà soát định kỳ | H6 |

### Phần cố định cho nợ và nền tảng

Mỗi sprint dành một phần năm số điểm cho các món trong `tech-debt-register.md`
và việc nền tảng (như sao lưu sang region thứ hai). Món nợ được chọn theo lãi
mỗi lần sửa và chi phí trả ghi trong sổ, món đắt lãi nhất và rẻ trả nhất đi
trước. Phần này cố định để việc trả nợ không phải thắng một tính năng ở mỗi
lần lập kế hoạch: so từng lần, tính năng gần như luôn thắng.

### Đã dời

Mỗi lần một mục đổi tầm, đội ghi lại lý do, để người theo dõi roadmap thấy một
quyết định chứ không thấy một lần trễ.

| Mục | Từ → sang | Lý do | Sprint |
|---|---|---|---|
| Khách nhận email thật qua Dịch vụ A | Bây giờ → Tiếp theo | Chưa có production để nối vào; ADR 0024 không đổi code ở stage-4 | 23 |

### Xem lại

Mỗi quý, cùng `technical-strategy.md`, và mỗi khi chiến lược đổi. Ngoài ra dự
báo của mục "Bây giờ" được tính lại ở mỗi sprint planning.

# Kế hoạch trực của Đơn Hàng

Trạng thái: kế hoạch, chưa chạy thật (xem mục Khoảng trống). Tài liệu ghi ai
trực, trực thế nào, alert nào được gọi người, và gọi tiếp ai khi người trực
không trả lời. Mọi con số về thời gian là giả định; đội xem lại sau ba tháng
trực thật.

### Lịch trực

Trực là được ghi tên là người trả lời, trong một khoảng thời gian đã thống
nhất, trong một thời gian phản hồi đã thống nhất.

- Luân phiên gồm bốn lập trình viên của đội. Mỗi ca dài một tuần, đổi ca vào
  sáng thứ Hai lúc 10:00.
- Mỗi ca có hai vai trò: người trực chính nhận mọi lần gọi; người trực phụ là
  người của ca kế tiếp, nhận lần gọi khi người trực chính không xác nhận.
- Lịch bốn tuần tới được ghi sẵn; ai cần đổi ca thì tự tìm người đổi và sửa
  lịch trước khi ca bắt đầu.
- Product owner, scrum master và tester không ở trong luân phiên.

Bốn người nghĩa là mỗi người trực chính một tuần trong bốn tuần, cộng một tuần
trực phụ. Đội biết con số này nhỏ; tổ chức trực cho bền là việc của trưởng nhóm
cùng các đội khác khi đội tách ra.

### Thời gian phản hồi (giả định)

| Việc | Trong giờ làm việc | Ngoài giờ làm việc |
|---|---|---|
| Xác nhận lần gọi | 5 phút | 15 phút |
| Bắt đầu xử lý theo runbook | 15 phút | 30 phút |

Xác nhận là báo đã nhận, để hệ thống không gọi tiếp người trực phụ. Người trực
có máy tính và truy cập được cluster, repo cấu hình và Prometheus trong suốt
ca.

### Alert nào được gọi người

Chỉ alert có nhãn `severity: page` được gọi người trực
(`docs/design/alerts.md`). Đó là các alert burn rate nhanh của S1–S4: khách
đang gặp lỗi hay chậm với tốc độ tiêu hết error budget trong vài ngày.

Alert `severity: ticket` không gọi ai. Nó thành một việc trong backlog, đội xử
lý trong giờ làm việc như việc khác. Alert theo nguyên nhân (dead-letter queue,
restore test, Job lỗi) cũng ở mức này.

### Bàn giao ca

Cuối mỗi ca, người trực chính viết một ghi chú bàn giao cho người kế tiếp:

- Các lần bị gọi trong ca, đã xử lý thế nào, còn mở gì.
- Thay đổi đang chạy dở trên staging hay production (một canary đang ở bước
  nào, một revert chưa làm lại).
- Alert `ticket` mới mở trong ca.

Hai người đọc ghi chú cùng nhau mười lăm phút lúc đổi ca. Ca chỉ chuyển khi người
mới đã nhận.

### Chuyển cấp

Chuyển cấp là thứ tự gọi tiếp khi người được gọi không xác nhận kịp hoặc cần
thêm người. Thứ tự này viết sẵn để một lần gọi bị lỡ không bỏ khách lại không
có ai:

1. Người trực chính.
2. Người trực phụ, khi người trực chính không xác nhận trong thời gian ở bảng
   trên.
3. Trưởng nhóm, khi cả hai không xác nhận, hoặc khi sự cố ở mức SEV1
   (`docs/team/incident-response.md`).
4. Product owner, để báo cho cửa hàng, khi sự cố kéo dài quá 30 phút (giả
   định).

Người trực được gọi thêm người bất cứ lúc nào thấy cần, không phải đợi tới
bước sau. Gọi thêm người không bị coi là yếu kém.

### Xem lại mọi lần gọi

Sau mỗi ca, người trực và trưởng nhóm xem lại từng lần gọi trong ca:

- Lần gọi phải làm gì đó: giữ alert, xem runbook có đủ không.
- Lần gọi không cần làm gì: hạ alert xuống `ticket`, hoặc xóa nó. Mỗi lần gọi
  vô ích làm người trực quen bỏ qua alert, tới lúc bỏ qua cả alert quan trọng.
- Sự cố tiêu hơn một phần tư budget của một SLI: viết postmortem theo
  `slo.md` và `docs/postmortems/template.md`.

Kết quả xem lại ghi vào ghi chú bàn giao của ca kế tiếp.

### Khoảng trống

Kế hoạch này chưa gọi được ai thật:

- Prometheus giữ trạng thái alert (pending, firing) nhưng không tự gửi thông
  báo. Cần một thành phần nhận alert từ Prometheus, gom, tắt tạm và gửi tới
  người trực; Đơn Hàng chưa chọn thành phần đó.
- Staging không chạy thành phần gửi thông báo nào; alert chỉ xem được bằng cách
  hỏi Prometheus của staging.
- Production chưa có Prometheus, nên chưa có alert nào về production.

Cho tới khi có ba thứ đó, người trực của tuần xem Prometheus của staging mỗi
sáng, và lịch trực ở trên chỉ dùng cho diễn tập (`scripts/devops/incident-drill.sh`).

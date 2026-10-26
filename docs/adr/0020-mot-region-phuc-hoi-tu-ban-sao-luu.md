# 0020. Chạy ở một region, phục hồi ở region thứ hai từ bản sao lưu

Trạng thái: Đã chấp nhận
Ngày: đề xuất đầu Sprint 21, quyết định cuối tuần đầu Sprint 21
Người quyết định: trưởng nhóm
Hạn góp ý: hết thứ Sáu tuần đầu Sprint 21

### Bối cảnh

Region là một vùng của nhà cung cấp hạ tầng, đủ xa để một sự cố lớn (mất
điện, mất mạng cả vùng) không chạm tới region khác. Đơn Hàng chạy ở một
region. Câu hỏi là có cần chạy ở hai region không, để còn phục vụ khi một
region mất.

Những gì đã có:

- SLO của api ghi trong `slo.md`.
- Một PostgreSQL primary giữ mọi đơn. `db-replica` (profile `replica` của
  Compose) là bản sao bất đồng bộ, đi sau primary một khoảng.
- WAL được lưu liên tục vào volume `wal-archive`; `archive_timeout` 60 giây
  đóng đoạn WAL kể cả khi ít ghi. `base-backup.sh` lấy base backup,
  `pitr.sh` khôi phục tới một thời điểm.
- `dr-drill.sh` dựng lại staging từ đầu theo các bước đã viết (OpenTofu,
  controller, Git server từ bản mirror, Argo CD) và đo thời gian từng bước.

Pod và cấu hình dựng lại được ở bất kỳ cluster nào từ repo cấu hình. Dữ liệu
thì không: đơn chỉ có trong database.

### Các phương án

- A. Một region; khi region mất, phục hồi ở region thứ hai từ base backup và
  WAL đã được sao sang đó, theo các bước của DR drill. Không thêm thành phần
  nào chạy thường trực. Mất dữ liệu tối đa (RPO) bằng phần WAL chưa sao sang;
  thời gian phục hồi (RTO) bằng thời gian DR drill đo được cộng thời gian
  khôi phục database.
- B. Standby ấm: một cluster thứ hai ở region khác do Argo CD đồng bộ từ cùng
  repo cấu hình, cùng một replica PostgreSQL bất đồng bộ. Failover thủ công,
  chỉ sau khi primary cũ đã bị dừng hoặc cắt khỏi mọi client. RTO và RPO thấp
  hơn A nhiều, nhưng cluster thứ hai chạy và tốn tiền cả khi không dùng, và đội
  phải giữ, nâng cấp, diễn tập hai cluster.
- C. Active-active: cả hai region nhận đơn cùng lúc. Cần mỗi đơn thuộc về một
  region riêng hoặc một database ghi được ở nhiều nơi. Không hợp một
  PostgreSQL primary và một bản triển khai cho mọi cửa hàng (ADR 0012).

### Quyết định

Chọn A. SLO hiện tại không đòi RTO hay RPO mà A không đạt, và chưa hợp đồng
nào đòi. B tốn một cluster thường trực và gấp đôi việc vận hành để bảo vệ khỏi
một sự cố hiếm hơn nhiều so với những sự cố một region đã chịu được (mất một
node, mất một Pod). C đòi đổi cách chia dữ liệu mà ADR 0013 đã quyết, không
thuộc phạm vi ADR này.

### Hệ quả

- RTO và RPO của Đơn Hàng là số đo của DR drill và tần suất sao WAL sang
  region thứ hai, không phải con số đội mong muốn. Mỗi lần DR drill cập nhật
  hai số này.
- Khoảng trống hiện tại: bản sao lưu và WAL chưa rời khỏi máy đang chạy
  database. Mất máy đó là mất cả bản sao lưu. Sao chúng sang region thứ hai là
  việc cần làm trước khi có khách thật; stage-4 chưa làm.
- Một replica bất đồng bộ không được promote khi primary còn có thể nhận ghi:
  cả hai sẽ nhận đơn và lệch nhau. `promote-replica.sh` cho thấy điều đó.

Điều kiện mở lại:

- Một hợp đồng hoặc SLA đòi RTO hoặc RPO thấp hơn số đo của DR drill.
- Dữ liệu của một số cửa hàng phải nằm ở một vùng xác định.

### Ý kiến đã nhận

Product owner hỏi một giờ ngừng phục vụ có chấp nhận được không. Câu trả lời:
tùy SLO: một sự cố mất cả region có thể tiêu hết error budget của cả cửa sổ
SLO trong `slo.md`, và đội chấp nhận điều này cho một sự cố hiếm. Quyết
định không đổi; câu hỏi được ghi lại để xem lại khi SLO đổi.

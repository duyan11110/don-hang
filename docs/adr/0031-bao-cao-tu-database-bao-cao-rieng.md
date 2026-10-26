# 0031. Báo cáo đọc từ database báo cáo riêng, nạp bằng job mỗi giờ

Trạng thái: Đã chấp nhận
Ngày: đề xuất giữa Sprint 26, quyết định cuối Sprint 26
Người quyết định: trưởng nhóm, cùng product owner
Hạn góp ý: hết thứ Sáu tuần thứ hai Sprint 26

Chưa xây ở stage-4: không có database báo cáo hay job nào trong repo. Thiết kế
và buổi review ở `docs/design/reporting-design-review.md`.

### Bối cảnh

`docs/team/reporting-requirements.md`: báo cáo không lấy sức chứa của đặt đơn,
mỗi cửa hàng chỉ thấy số của mình, báo cáo gộp có cả cửa hàng ở database riêng
(ADR 0026), số cũ nhiều nhất 2 giờ (giả định). Doanh thu cần cả `donhang` và
`donhang_payments`, hai database không join được trong một truy vấn.
`OrderMessage` chỉ có id đơn, email, tên khách và thời điểm.

### Các phương án

- Báo cáo chạy trên primary: không thêm gì, nhưng truy vấn dài giữ kết nối mà
  đặt đơn cần (trái driver 1), và vẫn không join được hai database.
- Báo cáo chạy trên `db-replica`: không lấy kết nối của primary, nhưng replica
  là bản sao cả server `db`: vẫn không join hai database trong một truy vấn, và
  không có database riêng của cửa hàng đã chuyển.
- Read model nuôi từ message: số mới hơn, nhưng `OrderMessage` không có số tiền
  hay dòng hàng; thêm vào là đổi schema mà mọi bên đọc phải nhận, và đơn cũ
  không đọc lại được từ broker.
- Database báo cáo riêng, nạp bằng job theo lịch (ETL): job đọc từng nguồn, ghi
  tổng vào một chỗ riêng; báo cáo chỉ đọc chỗ đó.

### Quyết định

Chọn database báo cáo riêng.

- Database báo cáo nằm trên server riêng (giả định).
- Mỗi giờ (giả định), một job đọc `donhang`, `donhang_payments` và mọi database
  mà bảng ánh xạ cửa hàng của ADR 0026 liệt kê, rồi ghi tổng theo cửa hàng theo
  ngày (giờ Việt Nam).
- Mỗi lần chạy tính lại 3 ngày gần nhất (giả định) và thay các dòng của những
  ngày đó: chạy lặp lại cho cùng kết quả; hủy hay hoàn tiền muộn vẫn tới đúng
  ngày.
- Mỗi dòng tổng mang shop id. Nhân viên cửa hàng đọc theo cửa hàng lấy từ
  access token (từ release 2), có row-level security như ADR 0013 (giả định).
- Truy vấn báo cáo chỉ đọc database báo cáo.
- Mất database báo cáo thì dựng lại từ nguồn, không khôi phục từ bản sao lưu.

### Hệ quả

- Số báo cáo cũ tới một giờ, cộng thời gian job chạy.
- Thêm một database, một server và một job phải chạy; đội Cửa hàng phụ trách
  (ADR 0025, giả định).
- Câu hỏi mới mà tổng theo ngày không trả lời (ví dụ doanh số theo giờ) cần một
  bảng tổng mới, nạp lại từ nguồn.
- Số tiền trong báo cáo là bản sao; chủ của mỗi con số vẫn là Ordering hay
  Payments (`data-ownership.md`).

Đội xem lại quyết định khi: có yêu cầu số liệu trực tiếp (khi đó message đơn
phải mang số tiền); có câu hỏi mà tổng theo ngày không trả lời kịp, khi đó cần
một nơi lưu dành riêng cho truy vấn phân tích trên dữ liệu chi tiết.

### Ý kiến đã nhận

Lập trình viên backend hỏi sao không dùng luôn `db-replica` cho rẻ. Replica
không join được hai database và không có cửa hàng ở database riêng; nó không
trả lời BC-3. Quyết định không đổi.

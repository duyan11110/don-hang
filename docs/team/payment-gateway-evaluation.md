# Đánh giá cổng thanh toán cho hoàn tiền

Đội Đơn Hàng làm trong tuần đầu Sprint 15, trước khi viết job gửi yêu cầu hoàn
tiền. Hai ứng viên được gọi là Cổng A và Cổng B; mọi con số về họ trong file
này là giả định để minh họa, không phải của vendor thật. Quyết định chọn cổng
ở ADR 0010 (`docs/adr/0010-cong-thanh-toan-ben-ngoai.md`).

### Tiêu chí, viết trước khi xem ứng viên

Mỗi tiêu chí lấy từ `refund-requirements.md` hoặc sổ rủi ro
(`risk-register-example.md`), không từ tài liệu giới thiệu của vendor. Tiêu
chí loại ngay đánh dấu "Loại ngay": ứng viên không đạt thì bị loại trước khi
so bất cứ điều gì khác, kể cả giá.

| Số | Tiêu chí | Nguồn | Loại ngay |
|---|---|---|---|
| T1 | Nhận idempotency key: gửi lại cùng key không hoàn tiền lần hai | YC-9, R2 | Loại ngay |
| T2 | Trả kết quả hoàn tiền ngay trong câu trả lời của lời gọi | thiết kế bước 6, R1 | |
| T3 | Có môi trường test, và môi trường đó chạy đúng như tài liệu | R1 | Loại ngay |
| T4 | Hoàn tiền được cho đơn chuyển khoản ngân hàng | câu hỏi mở của yêu cầu | |
| T5 | Thời hạn tối đa để hoàn tiền sau khi thanh toán | câu hỏi mở của yêu cầu | |
| T6 | Trả lý do khi từ chối hoàn tiền, để nhân viên xử lý | YC-6, R4 | |
| T7 | Xuất được lịch sử hoàn tiền cho kế toán | mục tiêu 2 của yêu cầu, R5 | |

### Kết quả, thử trên môi trường test

Rủi ro R1 nói API hoàn tiền có thể chạy khác tài liệu, nên đội thử chứ không
đọc: mỗi tiêu chí là một lời gọi thật tới môi trường test của từng cổng.

| Số | Cổng A | Cổng B |
|---|---|---|
| T1 | Có: gửi lại cùng key trả lại đúng kết quả lần đầu, không tạo hoàn tiền mới | Không: tài liệu không nhắc tới; gửi hai lần tạo hai hoàn tiền |
| T2 | Có | Không: trả "đang xử lý", kết quả gọi ngược vào hệ thống sau |
| T3 | Có, chạy đúng tài liệu ở mọi lời gọi đã thử | Có, nhưng mã lỗi khác tài liệu ở hai lời gọi |
| T4 | Không: từ chối với lý do "chuyển khoản không hoàn qua cổng thẻ" | Có |
| T5 | 180 ngày | 120 ngày |
| T6 | Có, lý do bằng chữ trong câu trả lời 422 | Chỉ mã số, phải tra bảng |
| T7 | Có, tải CSV mọi lúc từ trang quản trị và qua API | Có, chỉ qua trang quản trị, mỗi tháng một lần |

Cổng B bị loại ở T1. Các dòng còn lại của Cổng B vẫn được ghi để lần đánh giá
sau không phải thử lại.

### Hai câu hỏi mở của yêu cầu, nay đã đóng

- Hoàn tiền tối đa bao nhiêu ngày sau khi thanh toán: với Cổng A là 180 ngày.
  Đơn quá hạn đó do nhân viên xử lý tay.
- Đơn chuyển khoản ngân hàng có hoàn qua cổng được không: với Cổng A thì
  không. Cổng từ chối, yêu cầu thành `failed` kèm lý do và hiện trong danh
  sách của nhân viên (YC-6); chăm sóc khách hàng chuyển khoản lại bằng tay,
  như cách xử lý R4.

### Cam kết dịch vụ (SLA), quy ra thời gian

Phần trăm khó hình dung, nên mỗi cam kết được quy ra thời gian cổng được phép
không chạy trong một tháng 30 ngày (43.200 phút).

| | Cổng A | Cổng B |
|---|---|---|
| Khả dụng hằng tháng | 99,9%: tối đa khoảng 43 phút không chạy | 99,5%: tối đa khoảng 3 giờ 36 phút |
| Cách đo | Lời gọi API thành công, đo phía cổng | Trang trạng thái của cổng |
| Không tính | Bảo trì báo trước 72 giờ | Bảo trì báo trước 24 giờ, sự cố của ngân hàng |
| Khi không giữ lời | Trả lại 10% phí tháng đó | Không có |
| Trả lời hỗ trợ khi sự cố nặng | 1 giờ, mọi lúc | 1 ngày làm việc |

Tiền trả lại chỉ là một phần phí, không bù các đơn bị mất, nên SLA không
chuyển được bao nhiêu rủi ro sang vendor. Đơn Hàng không dựa vào SLA cho yêu
cầu của mình: yêu cầu hoàn tiền vẫn được nhận khi cổng lỗi và được gửi lại
trong 24 giờ (YC-7, YC-10), dù cổng hứa gì.

### Điều khoản hợp đồng kỹ sư cần đọc

Luật sư xem phần pháp lý. Các điều khoản dưới đây quyết định chi phí kỹ thuật
nên đội tự đọc. Cột cuối đánh dấu điều phải có bằng văn bản trước khi ký.

| Điều khoản | Cổng A | Cổng B | Phải có văn bản trước khi ký |
|---|---|---|---|
| Xuất dữ liệu: gì, định dạng nào, khi nào | Lịch sử hoàn tiền dạng CSV, mọi lúc | CSV hằng tháng | Có: xuất được lịch sử hoàn tiền cả sau khi hợp đồng kết thúc |
| Giữ dữ liệu sau khi hợp đồng kết thúc, rồi xóa | 90 ngày, rồi xóa và gửi xác nhận | Không nói | Có |
| Báo trước khi đổi hoặc bỏ một phiên bản API | 6 tháng | 1 tháng | Có |
| Đổi giá khi gia hạn | Tăng tối đa 10% mỗi năm | Không giới hạn | Có |
| Thời hạn hợp đồng và thời gian báo trước khi chấm dứt | 1 năm, tự gia hạn, báo trước 60 ngày | 2 năm, báo trước 90 ngày | Không |

### Ngoài tính năng

- Hỗ trợ trong lúc thử: Cổng A trả lời hai câu hỏi kỹ thuật trong ngày, có
  người đọc được log của lời gọi; Cổng B trả lời sau ba ngày bằng đường dẫn tới
  tài liệu.
- Cách báo thay đổi: Cổng A có trang thay đổi theo phiên bản API và gửi email
  cho kỹ sư đã đăng ký; Cổng B đăng tin trên trang chủ.

Đội sẽ sống với cả hai điều này nhiều năm, nên chúng được ghi cạnh tính năng.

### Môi trường test trong lab

`fake-gateway/` trong repo đóng vai môi trường test của Cổng A: nhận
`Idempotency-Key`, trả kết quả ngay, từ chối hoàn tiền đơn chuyển khoản (đơn 3
và 8) với lý do bằng chữ. Nếu đổi cổng, file này được đánh giá lại và
`fake-gateway/` đổi theo cổng mới.

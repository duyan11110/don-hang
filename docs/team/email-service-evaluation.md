# Đánh giá dịch vụ gửi email cho khách

Đội Đơn Hàng làm trong Sprint 23, trước khi có khách thật. Mọi con số trong
file này là giả định để minh họa, không phải của nhà cung cấp thật nào; hai
dịch vụ bên ngoài được gọi là Dịch vụ A và Dịch vụ B. Quyết định ở ADR 0024
(`docs/adr/0024-dich-vu-gui-email-ben-ngoai.md`).

### Bối cảnh

`self-run-components.md` ghi: gửi email cho khách là năng lực còn phải mua.
Mailpit chỉ bắt email trong lab, không gửi. Notifications gửi email đơn hàng
và email báo đã hoàn tiền (YC-5 của `refund-requirements.md`) qua
`IEmailSender`, do `MailKitEmailSender` cài đặt bằng SMTP.

Ba phương án:

- Dịch vụ A: dịch vụ gửi email bên ngoài.
- Dịch vụ B: dịch vụ gửi email bên ngoài khác.
- Tự chạy máy chủ gửi email, như các thành phần trong `self-run-components.md`.

Lần đánh giá này dùng ma trận chấm điểm có trọng số: mỗi phương án được chấm
theo từng tiêu chí, điểm nhân với trọng số của tiêu chí rồi cộng lại, để so
những phương án mạnh ở những chỗ khác nhau trên một thang.

### Tiêu chí loại ngay

Kiểm trước, không có trọng số. Phương án không đạt một tiêu chí thì bị loại,
dù tổng điểm của nó có thể là bao nhiêu.

| Số | Tiêu chí | Vì sao | Dịch vụ A | Dịch vụ B | Tự chạy |
|---|---|---|---|---|---|
| L1 | Nhận email qua SMTP có TLS, có đăng nhập | Notifications giữ `MailKitEmailSender`: lớp này hôm nay nối Mailpit không TLS, nên chỉ cần thêm cấu hình TLS và đăng nhập, không viết lớp gửi mới | Đạt | Đạt | Đạt |
| L2 | Có môi trường test, gửi được mà không tới hộp thư thật | Thử cách nối trước khi gửi cho khách | Đạt | Đạt | Đạt: một bản cài thứ hai |
| L3 | Xuất được danh sách địa chỉ bị trả lại hoặc bị chặn | Không mất danh sách khi rời đi | Đạt: mọi lúc, qua API | Đạt: mỗi tháng một lần, qua trang quản trị | Đạt: dữ liệu ở máy của đội |

Không phương án nào bị loại.

### Trọng số, chốt trước khi chấm

Product owner và trưởng nhóm chốt bảng này trước lần gửi thử đầu tiên, khi
chưa ai thấy điểm của phương án nào. Trọng số viết trước thì không bị kéo về
phía phương án ai đó đã thích.

| Số | Tiêu chí | Trọng số | Lý do | Nguồn |
|---|---|---|---|---|
| K1 | Email tới hộp thư chính của khách, không vào thư rác (đo bằng gửi thử) | 30 | Email không tới thì mọi thứ khác không đáng kể | YC-5 của `refund-requirements.md`; email đơn hàng giữ như hôm nay (`multi-shop-requirements.md`, mục Không đổi) |
| K2 | Báo từng email bị trả lại, để Notifications ngừng gửi tới địa chỉ đó | 20 | Gửi lặp tới địa chỉ hỏng làm dịch vụ hạ uy tín người gửi, kéo theo email của mọi cửa hàng | Rủi ro E1 bên dưới |
| K3 | TCO 3 năm, gồm giờ của đội | 25 | Phí rẻ không có nghĩa là rẻ nếu đội phải tự lo phần còn lại | `self-run-components.md` |
| K4 | Điều khoản rời đi: giữ dữ liệu sau khi hợp đồng kết thúc, xóa có xác nhận, thời gian báo trước khi chấm dứt | 15 | Đổi dịch vụ phải làm được mà không mất dữ liệu | Cách đọc điều khoản trong `payment-gateway-evaluation.md` |
| K5 | Hỗ trợ khi sự cố | 10 | Email đến muộn đã được chấp nhận (R6), nên hỗ trợ nhẹ ký hơn | R6 của `risk-register-example.md` |
| | Tổng | 100 | | |

Rủi ro E1 (giả định, ghi cho lần đánh giá này): Notifications gửi lại nhiều
lần tới một địa chỉ không tồn tại, dịch vụ gửi email coi Đơn Hàng là người gửi
xấu và chậm hoặc chặn mọi email của nó.

### Điểm

Thang 1–5, 5 là tốt nhất. Mỗi điểm ghi bằng chứng, để người đọc cãi một điểm
chứ không cãi cả tổng.

| Tiêu chí | Phương án | Điểm | Bằng chứng |
|---|---|---|---|
| K1 | Dịch vụ A | 4 | Gửi thử 1.000 email tới 20 hộp thư thử ở 5 nhà cung cấp hộp thư: 94% vào hộp thư chính (giả định) |
| K1 | Dịch vụ B | 5 | Cùng lần gửi thử: 97% (giả định) |
| K1 | Tự chạy | 2 | Cùng lần gửi thử từ một máy chủ mới: 70% (giả định); địa chỉ gửi chưa có uy tín |
| K2 | Dịch vụ A | 4 | Gọi ngược vào hệ thống cho mỗi email bị trả lại, trong vài phút (giả định), thử trên môi trường test |
| K2 | Dịch vụ B | 3 | Gọi ngược cho email bị trả lại, nhưng địa chỉ bị người nhận đánh dấu thư rác chỉ hiện trong trang quản trị (giả định) |
| K2 | Tự chạy | 2 | Phải tự đọc log của máy chủ gửi và viết phần báo lại cho Notifications |
| K3 | Dịch vụ A | 3 | 48 ngày công trong 3 năm: phí quy ra 36, giờ của đội 12 (giả định) |
| K3 | Dịch vụ B | 4 | 42 ngày công: phí quy ra 30, giờ của đội 12 (giả định) |
| K3 | Tự chạy | 1 | 117 ngày công: máy 9, vận hành 3 ngày công mỗi tháng (giả định) |
| K4 | Dịch vụ A | 5 | Hợp đồng mẫu: giữ dữ liệu 30 ngày rồi xóa và gửi xác nhận; báo trước 30 ngày khi chấm dứt (giả định) |
| K4 | Dịch vụ B | 3 | Hợp đồng mẫu không nói về xóa dữ liệu; báo trước 90 ngày (giả định) |
| K4 | Tự chạy | 5 | Không có hợp đồng; dữ liệu ở máy của đội |
| K5 | Dịch vụ A | 4 | Trả lời sự cố nặng trong 1 giờ, mọi lúc; trả lời hai câu hỏi trong lúc thử trong ngày (giả định) |
| K5 | Dịch vụ B | 3 | Trả lời trong 1 ngày làm việc (giả định) |
| K5 | Tự chạy | 1 | Không ai ngoài đội; đội chưa ai từng vận hành máy chủ gửi email |

Tổng có trọng số (điểm × trọng số, tối đa 500):

| Phương án | K1 | K2 | K3 | K4 | K5 | Tổng |
|---|---|---|---|---|---|---|
| Dịch vụ A | 120 | 80 | 75 | 75 | 40 | 390 |
| Dịch vụ B | 150 | 60 | 100 | 45 | 30 | 385 |
| Tự chạy | 60 | 40 | 25 | 75 | 10 | 210 |

### Độ nhạy

Trọng số là ước đoán, nên đội đổi từng trọng số 10 điểm lên hoặc xuống và
chia phần chênh đều cho bốn tiêu chí còn lại (mỗi tiêu chí 2,5), để tổng vẫn
là 100.

| Thay đổi | Dịch vụ A | Dịch vụ B | Tự chạy | Đứng đầu |
|---|---|---|---|---|
| Không đổi | 390 | 385 | 210 | A |
| K1 +10 | 390 | 402,5 | 207,5 | B |
| K1 −10 | 390 | 367,5 | 212,5 | A |
| K2 +10 | 390 | 377,5 | 207,5 | A |
| K2 −10 | 390 | 392,5 | 212,5 | B |
| K3 +10 | 377,5 | 390 | 195 | B |
| K3 −10 | 402,5 | 380 | 225 | A |
| K4 +10 | 402,5 | 377,5 | 245 | A |
| K4 −10 | 377,5 | 392,5 | 175 | B |
| K5 +10 | 390 | 377,5 | 195 | A |
| K5 −10 | 390 | 392,5 | 225 | B |

A và B đổi chỗ ở năm trong mười trường hợp, chênh nhau không quá 25 điểm
trên 500. Tự chạy đứng cuối trong mọi trường hợp, vì giờ vận hành kéo K3 và K5
xuống.

### Kết luận

A và B ngang nhau theo ma trận; tự chạy bị loại khỏi lựa chọn. Quyết định giữa
A và B ở ADR 0024, bằng lý do nằm ngoài các tiêu chí đã chấm.

Mức giả định để theo dõi sau khi chọn: tỉ lệ email vào hộp thư chính từ 90%
trở lên, và TCO không vượt số của bảng K3 cho phương án được chọn.

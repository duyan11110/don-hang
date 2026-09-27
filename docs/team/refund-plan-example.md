# Kế hoạch luồng hoàn tiền (lập ở Sprint 15 planning)

Luồng hoàn tiền là story product owner hứa trong `meeting-notes-example.md`:
khách tự yêu cầu hoàn tiền cho đơn đã thanh toán. Yêu cầu chi tiết ở
`refund-requirements.md`. Đội Đơn Hàng ước lượng hai loại việc bằng hai cách
khác nhau.

## Việc đã quen: story point

Những việc giống việc đội đã làm xong (màn hình, API, job gửi email) được ước
lượng bằng story point như mọi sprint, và dự báo bằng velocity (xem
`velocity-history.md`).

| Việc | Điểm |
|---|---|
| Nút "Yêu cầu hoàn tiền" và trạng thái hoàn tiền trên màn hình đơn | 5 |
| Nhận yêu cầu hoàn tiền của khách, lưu người yêu cầu và thời điểm | 5 |
| Job nền gửi yêu cầu hoàn tiền, thử lại khi lỗi (giống job gửi email) | 5 |
| Chặn yêu cầu hoàn tiền thứ hai cho cùng một đơn | 2 |
| Chỉ khách của đơn được yêu cầu hoàn tiền | 3 |
| Email báo khách kết quả hoàn tiền | 3 |
| Danh sách yêu cầu bị cổng thanh toán từ chối cho nhân viên | 5 |
| Cộng | 28 |

## Việc chưa từng làm: ước lượng ba điểm

Đội chưa từng gọi API hoàn tiền của cổng thanh toán, chưa từng đối soát với kế
toán, nên không có việc cũ nào để so điểm. Hai việc này được ước lượng bằng ngày
công của một người, mỗi việc ba giá trị: lạc quan (O), khả dĩ nhất (M), bi quan
(P). Một lập trình viên làm cả hai, từ Sprint 15.

| Việc | O | M | P | (O + 4M + P) / 6 |
|---|---|---|---|---|
| Tích hợp API hoàn tiền của cổng thanh toán | 4 | 6 | 14 | 7 |
| Đối soát hoàn tiền với kế toán | 2 | 4 | 12 | 5 |
| Cộng hai việc | | | | 12 |
| Buffer: một nửa tổng (P − M) = ((14 − 6) + (12 − 4)) / 2 | | | | 8 |
| Tổng phần ước lượng ba điểm | | | | 20 |

Khoảng cách giữa O và P của việc tích hợp là 10 ngày: đội biết rất ít về cổng
thanh toán. Khoảng cách rộng là thông tin cho kế hoạch, không phải một ước lượng
tồi. (O + 4M + P) / 6 nghiêng về giá trị khả dĩ nhất nhưng bị kéo về phía bi
quan khi P xa M.

Buffer là một dòng riêng, không chia nhỏ vào từng việc. Nó tính từ khoảng cách
giữa bi quan và khả dĩ nhất, nên việc nào càng bất định thì góp vào buffer càng
nhiều. Mỗi sprint review, đội ghi đã dùng bao nhiêu ngày buffer. Buffer chỉ
dành cho độ bất định của hai việc trên; việc mới xin thêm không lấy từ buffer mà
đưa về product owner để đổi lại kế hoạch.

## Kết luận

20 ngày công là khoảng hai sprint của một lập trình viên, chạy song song với 28
điểm story point của ba người còn lại. Cả luồng hoàn tiền: từ 4 đến 5 sprint,
tính từ đầu Sprint 15 (cách tính ở `velocity-history.md`). Kế hoạch này được
xem lại ở mỗi sprint planning, cùng với `risk-register-example.md`.

Buffer đã dùng: 0 / 8 ngày (cập nhật ở mỗi sprint review).

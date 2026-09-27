# Velocity của đội Đơn Hàng, Sprint 10 đến Sprint 14

Mỗi sprint dài hai tuần. Velocity của một sprint là tổng điểm của những việc
đạt Definition of Done trong sprint đó. Việc chưa xong tính 0 điểm ở sprint
này và được tính ở sprint làm xong nó.

## Năm sprint gần nhất

| Sprint | Điểm đã nhận | Velocity | Ghi chú |
|---|---|---|---|
| 10 | 10 | 8 | Một việc 2 điểm chưa có test nên chưa xong, chuyển Sprint 11 |
| 11 | 11 | 11 | |
| 12 | 7 | 6 | Thiếu người: hai lập trình viên nghỉ phép một tuần, đội nhận ít hơn thường lệ; một việc 1 điểm chuyển Sprint 13 |
| 13 | 10 | 10 | |
| 14 | 11 | 9 | Việc "Ngừng gửi thông báo cho đơn đã hủy" (2 điểm) chưa xong, chuyển Sprint 15 |

Velocity đổi từ sprint này sang sprint khác, nên đội không dự báo bằng một
sprint duy nhất. Bốn sprint đủ người (10, 11, 13, 14) nằm trong khoảng 8 đến 11
điểm. Sprint 12 thiếu người nên không dùng làm mức thấp nhất cho một sprint đủ
người; nó cho thấy velocity giảm khi thiếu người.

## Dự báo cho backlog hoàn tiền (lập ở Sprint 15 planning)

Còn 30 điểm: 28 điểm việc hoàn tiền tính bằng story point (xem
`refund-plan-example.md`) và 2 điểm của việc chuyển từ Sprint 14.

| Trường hợp | Điểm mỗi sprint | 30 chia cho điểm, làm tròn lên |
|---|---|---|
| Cả bốn lập trình viên làm backlog này | 8 đến 11 | 30 / 11 ≈ 2,7 → 3 và 30 / 8 = 3,75 → 4: từ 3 đến 4 sprint |
| Một lập trình viên làm phần tích hợp cổng thanh toán | 6 đến 8 | 30 / 8 = 3,75 → 4 và 30 / 6 = 5: từ 4 đến 5 sprint |

Từ Sprint 15, một trong bốn lập trình viên làm phần việc đội chưa từng làm (tích
hợp API hoàn tiền của cổng thanh toán, đối soát với kế toán) và không nhận việc
tính bằng điểm. Ba người còn lại làm được khoảng ba phần tư mức thường lệ, nên
đội nhận 6 đến 8 điểm mỗi sprint thay vì 8 đến 11. Trường hợp này là trường hợp
đội dùng.

Câu trả lời cho "bao giờ xong": từ 4 đến 5 sprint, tức 8 đến 10 tuần tính từ
đầu Sprint 15. Không có một ngày duy nhất.

Dự báo được làm lại ở mỗi sprint planning, với velocity của sprint vừa xong và
số điểm còn lại. Một dự báo giữ nguyên từ Sprint 15 tới cuối sẽ dần thành một
lời hứa mà không ai quyết định hứa.

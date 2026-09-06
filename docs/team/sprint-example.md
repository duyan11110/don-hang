# Sprint 14 của đội Đơn Hàng

Độ dài: hai tuần. Đội: một product owner, một scrum master, bốn lập trình viên,
một tester.

## Mục tiêu sprint

> Khách hàng tự hủy được đơn chưa thanh toán mà không cần gọi tổng đài.

## Sprint backlog

| Việc | Người nhận | Ước lượng | Trạng thái cuối sprint |
|---|---|---|---|
| API `POST /api/v1/orders/{id}/cancel` | Dev 1 | 3 | Xong |
| Nút "Hủy đơn" trên màn hình đơn hàng | Dev 2 | 3 | Xong |
| Chặn hủy đơn đã thanh toán | Dev 1 | 2 | Xong |
| Ngừng gửi thông báo cho đơn đã hủy | Dev 3 | 2 | Chưa xong, chuyển sprint sau |
| Sửa lỗi tổng tiền sai ở đơn nhiều dòng | Dev 4 | 1 | Xong |

## Daily: ba câu của một junior

> Hôm qua tôi làm xong phần kiểm tra trạng thái đơn.
> Hôm nay tôi viết test cho trường hợp hủy hai lần.
> Tôi đang vướng: không biết đơn `shipped` có được hủy không, cần PO trả lời.

Câu thứ ba là câu quan trọng nhất. Daily không phải để báo cáo cho quản lý; nó
để cả đội sắp xếp lại một ngày.

## Sprint review

Đội trình diễn trên môi trường thử nghiệm, không phải trên máy cá nhân. Việc
"Ngừng gửi thông báo" chưa xong nên không được trình diễn — chưa xong thì chưa
tính, dù đã viết gần hết code.

## Retrospective

- Làm tốt: viết tiêu chí chấp nhận trước khi code, nhờ vậy không phải làm lại.
- Cần sửa: nhận việc phụ thuộc vào một người duy nhất.
- Hành động cho sprint sau: mỗi việc lớn hơn 3 điểm phải có hai người đọc code.

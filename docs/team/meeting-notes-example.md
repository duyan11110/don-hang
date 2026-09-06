# Biên bản họp: chọn cách chặn hủy đơn đã thanh toán

**Mục đích:** quyết định xem đơn `paid` có được hủy hay không.
**Người dự:** product owner, hai lập trình viên, tester.
**Thời lượng:** 20 phút.

## Quyết định

Đơn `paid` **không** hủy được từ ứng dụng. Khách hàng phải yêu cầu hoàn tiền.

## Lý do

Hoàn tiền cần đối soát với cổng thanh toán; đội chưa có phần đó. Cho phép hủy
mà không hoàn tiền sẽ tạo ra đơn đã hủy nhưng đã thu tiền — trạng thái không ai
xử lý được.

## Việc phải làm

| Việc | Ai | Khi nào |
|---|---|---|
| Thêm điều kiện trạng thái vào API hủy | Dev 1 | Trong sprint này |
| Ẩn nút "Hủy đơn" với đơn `paid` | Dev 2 | Trong sprint này |
| Viết story cho luồng hoàn tiền | PO | Trước sprint sau |

## Câu chưa trả lời

Đơn `shipped` mà khách từ chối nhận thì tính là gì? PO sẽ hỏi bộ phận vận hành.

---

## Một bản cập nhật trạng thái ba dòng

> Đang làm: API hủy đơn, xong phần kiểm tra trạng thái.
> Vướng: chưa rõ đơn `shipped` bị từ chối nhận thì xử lý thế nào — đã hỏi PO.
> Tiếp theo: viết test cho trường hợp hủy hai lần, xong trong hôm nay.

Ba dòng này thay được một cuộc họp. Nêu vấn đề sớm kèm phương án, đừng nêu muộn
kèm lời xin lỗi.

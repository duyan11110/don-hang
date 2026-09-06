# User story và tiêu chí chấp nhận

## Story

> Là **khách hàng**, tôi muốn **hủy đơn hàng chưa thanh toán của mình**
> để **không phải gọi tổng đài khi tôi đổi ý**.

## Tiêu chí chấp nhận

1. Khi đơn ở trạng thái `new` và thuộc về tôi, màn hình chi tiết đơn hiện nút
   "Hủy đơn".
2. Khi tôi bấm "Hủy đơn" và xác nhận, trạng thái đơn chuyển thành `cancelled`
   và màn hình hiện thông báo "Đã hủy đơn".
3. Khi đơn ở trạng thái `paid`, `shipped` hoặc `cancelled`, nút "Hủy đơn" không
   hiện.
4. Khi tôi gọi API hủy một đơn không thuộc về tôi, hệ thống trả về 403 và không
   thay đổi gì.
5. Khi tôi hủy cùng một đơn hai lần, lần thứ hai trả về 409 và trạng thái đơn
   vẫn là `cancelled`.

## Definition of Done của đội

- [ ] Code đã được ít nhất một người khác đọc và duyệt.
- [ ] Có test tự động cho mọi tiêu chí chấp nhận ở trên.
- [ ] Chạy được trên môi trường thử nghiệm, không chỉ trên máy người viết.
- [ ] Không thêm cảnh báo mới khi build.
- [ ] Tài liệu API đã cập nhật.

## Vì sao story này viết được, còn "làm chức năng hủy đơn" thì không

Story nói **ai** cần, **cái gì**, và **vì sao**. Tiêu chí chấp nhận biến câu đó
thành những thứ kiểm tra được. Không có tiêu chí, hai người sẽ hiểu "hủy đơn"
theo hai cách, và người kiểm thử hiểu theo cách thứ ba.

Story là lời hứa về một cuộc trao đổi, không phải bản đặc tả. Nếu có chỗ chưa
rõ, việc của người làm là hỏi trước khi code, không phải đoán rồi hy vọng.

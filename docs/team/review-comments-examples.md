# Nhận xét trong code review: viết thế nào và không viết thế nào

Các nhận xét dưới đây đều lấy từ pull request thêm chức năng hủy đơn.

## Nhận xét tốt

> **Bắt buộc sửa.** Ở `OrderService.Cancel`, đơn `shipped` cũng bị chuyển sang
> `cancelled`. Tiêu chí chấp nhận số 3 nói chỉ đơn `new` mới hủy được. Bạn thêm
> một điều kiện, hay mình hiểu sai tiêu chí?

> **Gợi ý, không bắt buộc.** Tên `flag` ở dòng 42 không cho biết nó là gì.
> `customerOwnsOrder` sẽ đọc thẳng ra nghĩa, và bỏ được comment ngay bên trên.

> **Câu hỏi.** Vì sao chỗ này bắt `Exception` chứ không bắt riêng
> `InvalidOperationException`? Nếu có lý do mình chưa thấy thì ghi lại một dòng
> giúp mình nhé.

> **Khen.** Test cho trường hợp hủy hai lần rất hay, mình không nghĩ ra.

## Nhận xét không tốt và lý do

| Nhận xét | Vấn đề |
|---|---|
| "Code này sai." | Không nói sai chỗ nào, sai thế nào. |
| "Bạn nên học lại về transaction." | Nói về người, không nói về code. |
| "Đổi hết sang LINQ đi." | Ý kiến cá nhân, không có lý do, không nói mức độ. |
| "OK." trên một PR 800 dòng | Duyệt mà không đọc; tệ hơn là không duyệt. |

## Khi bạn là tác giả

- Trả lời từng nhận xét, kể cả nhận xét bạn không đồng ý.
- Phân biệt rõ "đã sửa" và "không sửa, vì...".
- PR nhỏ nhận được nhận xét tốt hơn PR lớn, luôn luôn.
- Nhiều nhận xét không có nghĩa là bạn làm tệ. Nó có nghĩa là có người đọc kỹ.

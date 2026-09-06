# Mẫu câu hỏi

## Mẫu

```
Mục tiêu: <việc tôi đang cố làm xong>
Đã thử: <những gì tôi đã thử và kết quả từng cái>
Mong đợi: <tôi nghĩ điều gì sẽ xảy ra>
Thực tế: <điều đã xảy ra, kèm thông báo lỗi nguyên văn>
Môi trường: <phiên bản, môi trường, dữ liệu>
Tiếp theo: <việc tôi sẽ làm nếu không ai trả lời>
```

## Ví dụ điền đầy đủ

> **Mục tiêu:** cho khách hàng hủy đơn `new` qua API.
>
> **Đã thử:** gọi `POST /api/v1/orders/6/cancel` bằng `curl` — trả về 500. Đọc
> log, thấy `InvalidOperationException: order 6 has no total`. Chạy lại với đơn
> 9 thì cũng 500. Chạy `SELECT * FROM orders WHERE id = 6` thì đơn có tồn tại.
>
> **Mong đợi:** trả về 200 và trạng thái đơn thành `cancelled`.
>
> **Thực tế:** 500, log đính kèm ở dưới.
>
> **Môi trường:** môi trường thử nghiệm, nhánh `feature/cancel-order`, dữ liệu
> mẫu của lab.
>
> **Tiếp theo:** nếu 30 phút nữa chưa có ai trả lời, tôi sẽ thêm log vào
> `OrderService.Cancel` để xem giá trị nào bị thiếu.

## Vì sao mẫu này hoạt động

Viết xong bốn dòng đầu, rất nhiều lần bạn tự trả lời được câu hỏi — vì viết
buộc bạn phải thu hẹp phạm vi, đúng bước bạn đã bỏ qua.

Dòng cuối biến câu hỏi thành một quyết định: người đọc biết bạn không đứng yên
chờ, và biết khi nào cần chặn bạn lại.

## Hỏi khi nào

Đội thường thống nhất một khoảng thời gian, ví dụ 45 phút. Tự tìm trong khoảng
đó; hết khoảng đó thì hỏi. Hỏi quá sớm làm phiền người khác; hỏi quá muộn làm
mất cả ngày của chính bạn.

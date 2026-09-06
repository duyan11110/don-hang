# Một tính năng của Đơn Hàng đi qua những bước nào

Ví dụ có thật của đội: thêm nút "Hủy đơn" cho khách hàng.

## 1. Thu thập nhu cầu

Bộ phận chăm sóc khách hàng báo: mỗi ngày có khoảng mười cuộc gọi chỉ để xin hủy
đơn chưa giao. Product owner viết lại nhu cầu bằng một câu, không nói cách làm.

## 2. Thiết kế

Đội thống nhất: chỉ hủy được đơn ở trạng thái `new`; đơn đã `paid` phải qua bộ
phận hoàn tiền. Quyết định này được ghi lại vì nó thu hẹp phạm vi rất nhiều.

## 3. Xây dựng

Một người làm phần API, một người làm phần giao diện. Cả hai làm trên nhánh
riêng, mỗi ngày gộp code mới nhất từ nhánh chính về nhánh của mình.

## 4. Kiểm thử

Tiêu chí chấp nhận được viết trước khi code. Tester chạy lại đúng các tiêu chí
đó, cộng thêm một trường hợp không ai nghĩ tới: hủy đơn hai lần liên tiếp.

## 5. Phát hành

Tính năng lên môi trường thật vào đầu tuần, không phải chiều thứ sáu.

## 6. Vận hành

Sau một tuần, số cuộc gọi giảm còn hai mỗi ngày. Đội phát hiện thêm một lỗi:
đơn bị hủy vẫn gửi thông báo "đang giao". Lỗi này quay lại bước 1.

## Điều đáng chú ý

Sáu bước trên luôn xảy ra, kể cả khi không ai gọi tên chúng. Khác biệt giữa các
phương pháp làm việc chỉ là **kích thước một vòng**: làm cả sáu bước cho một
tính năng nhỏ trong hai tuần, hay làm cả sáu bước cho cả hệ thống trong một năm.
Vòng nhỏ không tạo ra ít tài liệu hơn; nó làm cho việc sai sớm rẻ hơn.

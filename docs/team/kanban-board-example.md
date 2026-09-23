# Bảng Kanban của đội Đơn Hàng

Đội không chia sprint cho nhánh sửa lỗi khẩn — việc vào bảng bất cứ lúc nào,
xếp theo mức ưu tiên, và bảng luôn phản ánh đúng trạng thái hiện tại.

## Các cột

| Việc cần làm | Đang làm (giới hạn 2) | Chờ review (giới hạn 2) | Xong |
|---|---|---|---|
| Thêm chỉ mục cho `orders.customer_id` | Sửa lỗi trang sản phẩm bị chậm — Dev 3 | Thêm log cho lần đăng nhập thất bại — Dev 1 | Vá lỗi mật khẩu rỗng vẫn đăng nhập được |
| Viết tài liệu API cho `/api/v1/orders` | Kiểm tra lại cảnh báo email bị gửi hai lần — Dev 2 | | Sửa định dạng số tiền ở trang admin |
| Dọn log cũ hơn 30 ngày | | | Cập nhật container Postgres |

## Vì sao "Đang làm" giới hạn hai việc

Dev 4 vừa xong một việc và định lấy việc thứ ba trong "Việc cần làm", nhưng
"Đang làm" đã có hai việc của Dev 2 và Dev 3. Trưởng nhóm chặn lại: giới hạn
nghĩa là dừng, đi giúp một việc đang có sẵn — ví dụ đọc review đang chờ ở cột
kế bên — thay vì mở việc mới. Một cột đầy là tín hiệu tắc nghẽn, không phải
chỗ trống cho người rảnh.

## Vì sao không có "sprint"

Nhóm hỗ trợ (Dev 1, Dev 2) nhận việc từ báo lỗi và câu hỏi của khách hàng bất
cứ ngày nào trong tuần; gom chúng vào một khối hai tuần sẽ làm chậm những việc
cần sửa ngay. Đội tính năng (Dev 3, Dev 4) vẫn dùng sprint riêng (xem
`sprint-example.md`) cho các việc lớn, có thể lên kế hoạch trước — hai đội
cùng công ty, khác cách tổ chức việc theo đúng loại việc mỗi đội nhận.

## Một việc di chuyển thế nào

"Vá lỗi mật khẩu rỗng vẫn đăng nhập được" đi qua đúng bốn cột: vào "Việc cần
làm" khi báo lỗi được xác nhận, sang "Đang làm" khi Dev 1 bắt đầu sửa, sang
"Chờ review" khi pull request mở, và sang "Xong" khi review xong và đã lên
môi trường thử nghiệm — không có bước nào bị bỏ qua, kể cả với lỗi khẩn.

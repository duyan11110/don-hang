# 0006. Secret trong repo cấu hình chỉ ở dạng đã mã hóa

Trạng thái: Đã chấp nhận
Ngày: đề xuất và quyết định trong Sprint 16
Người quyết định: trưởng nhóm
Hạn góp ý: hết tuần đầu Sprint 16

### Bối cảnh

Từ khi Argo CD triển khai từ repo cấu hình, mọi thứ cluster cần đều phải nằm
trong repo, trừ các Secret: mật khẩu database, khóa của api và Keycloak được
tạo bằng tay ngoài Git. Dựng lại cluster vì thế cần một người nhớ đủ các bước
tạo Secret, và Argo CD không biết Secret nào phải có.

### Các phương án

- Giữ Secret ngoài Git, tạo bằng script: không thêm thành phần nào, nhưng repo
  không mô tả đủ cluster và việc dựng lại phụ thuộc người chạy script.
- Đưa Secret vào repo ở dạng đã mã hóa bằng khóa công khai; một bộ điều khiển
  trong cluster giữ khóa riêng và giải mã thành Secret: repo mô tả đủ cluster,
  ai đọc được repo cũng không đọc được giá trị.
- Dùng một kho secret bên ngoài cluster và đồng bộ vào: mạnh nhất, nhưng thêm
  một dịch vụ phải chạy hoặc phải trả tiền, quá lớn cho một cluster lab.

### Quyết định

Chọn mã hóa trong repo. Mã hóa chỉ cần chứng chỉ công khai, không cần nói
chuyện với cluster. Khóa riêng được tạo trong thư mục `secrets/` (không vào
Git) và cài vào cluster bởi lớp platform.

### Hệ quả

- Khóa riêng mở được mọi secret trong repo: mất nó là mất mọi secret, lộ nó là
  lộ tất cả. Nó phải được sao lưu như dữ liệu.
- Một secret đã mã hóa chỉ giải mã được dưới đúng tên và namespace lúc mã hóa.
- Thêm một bộ điều khiển phải chạy và nâng cấp.

### Ý kiến đã nhận

Một lập trình viên phản đối: khóa riêng một nơi giữ là điểm hỏng duy nhất.
Đội giữ quyết định nhưng thêm một bước vào diễn tập khôi phục: dựng lại cluster
khi không có khóa để thấy điều gì hỏng, rồi dựng lại với khóa.

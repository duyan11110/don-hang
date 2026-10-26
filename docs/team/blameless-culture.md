# Văn hóa không đổ lỗi ở Đơn Hàng

Mẫu postmortem không đổ lỗi (`docs/postmortems/template.md`) chưa đủ. Nếu sau
sự cố người lãnh đạo hỏi "ai làm", mọi người học cách giấu điều mình biết, và
postmortem kế tiếp tìm được ít hơn. Tài liệu này ghi những điều người lãnh đạo
của đội (trưởng nhóm, product owner, và quản lý trực tiếp) cam kết giữ trước
mọi người, để ai cũng nhận được lỗi, hỏi được và báo được vấn đề mà không bị
phạt hay bị làm xấu hổ.

### Điều lãnh đạo cam kết

- Postmortem và số sự cố không bao giờ được dùng để đánh giá một người.
- Người báo một vấn đề đầu tiên được cảm ơn trước cả đội, kể cả khi vấn đề do
  chính họ gây ra.
- Sau sự cố, câu hỏi là điều gì đã cho phép nó xảy ra, không phải ai đã làm.
  Postmortem 0001 (`docs/postmortems/0001-doc-san-pham-tra-503.md`) là ví dụ:
  mục "Yếu tố góp phần" ghi rằng quy tắc "thay đổi cấu hình cũng qua canary"
  chưa được viết ra ở đâu, nên người làm có lý do hợp lý để nghĩ khác, và action
  item sửa quy trình, không nhắm vào người commit.

### Trách nhiệm vẫn còn

Không đổ lỗi không có nghĩa là không ai chịu trách nhiệm:

- Mỗi người vẫn giữ action item của mình tới khi xong, như cột "Người phụ
  trách" của postmortem.
- Mỗi người vẫn kể đúng phần mình trong buổi xem lại: đã thấy gì, đã làm gì,
  vì sao lúc đó thấy hợp lý.
- Một hành vi lặp lại của cùng một người được quản lý trực tiếp xử lý riêng,
  ngoài postmortem. Postmortem không phải chỗ cho việc đó.

### Số đo đọc theo đội và hệ thống

Bốn số đo phát hành (`delivery-metrics.md`) mô tả hệ thống phát hành, không
mô tả từng người, và không được dùng để xếp hạng ai. Số sự cố và số postmortem
cũng vậy.

### Dấu hiệu đang trượt

Mỗi quý, trưởng nhóm xem các dấu hiệu cho thấy mọi người bắt đầu ngại nói:

- Số lần suýt xảy ra sự cố được báo trong quý giảm, trong khi số deploy không
  giảm.
- Có sự cố mà cửa hàng phát hiện trước đội.
- Postmortem ngắn dần: ít yếu tố góp phần, dòng thời gian thiếu mốc.

Thấy một dấu hiệu thì đưa vào retrospective kế tiếp như một vấn đề của đội,
không đi tìm người im lặng.

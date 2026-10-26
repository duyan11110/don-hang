# Trực cho bền ở Đơn Hàng

Tài liệu này viết sau `on-call.md` và `incident-response.md` và không thay
chúng: `on-call.md` ghi lịch trực, thời gian phản hồi và chuyển cấp;
`incident-response.md` ghi mức nghiêm trọng và vai trò trong lúc xử lý. Ở đây
là những quy tắc để người trực còn nghỉ ngơi được, ca này qua ca khác. Mọi con
số là chính sách của dự án (giả định), đội xem lại sau ba tháng trực thật.

### Bao nhiêu người cho một vòng trực

Một vòng trực có gọi người ngoài giờ làm việc cần ít nhất năm người. Với ca dài
một tuần, năm người nghĩa là không ai trực chính quá một tuần trong năm tuần.

Vòng trực hiện tại (`on-call.md`) có bốn lập trình viên, ít hơn mức đó: mỗi
người trực chính một tuần trong bốn. Vì vậy, cho tới khi có đội thứ hai
(`team-structure.md`):

- Ngoài giờ làm việc, chỉ gọi người cho mức nghiêm trọng cao nhất của
  `incident-response.md`, tức SEV1.
- Alert của SEV2 bật ngoài giờ được xử lý vào đầu giờ làm việc kế tiếp.
- Trong giờ làm việc, gọi người như `on-call.md` ghi.

Khi đội tách theo ADR 0025, mỗi vòng trực mới cũng phải đủ năm người trước khi
gọi người ngoài giờ cho mọi alert `severity: page`.

### Đếm tải của từng người

Công bằng đo bằng tải mỗi người đã mang, không bằng số ca: hai người cùng trực
bốn ca có thể mang tải rất khác nhau. Mỗi tháng, trưởng nhóm đếm cho từng
người:

| Số đếm | Ghi chú |
|---|---|
| Số lần bị gọi | Mọi lần gọi, kể cả lần hóa ra vô ích |
| Số lần bị gọi ban đêm | Từ 22:00 tới 07:00 |
| Số ca cuối tuần hoặc ngày lễ | Ca có ít nhất một ngày cuối tuần hoặc ngày lễ |
| Số ca đã đổi | Ca đổi cho người khác và ca nhận đổi |

Người có tải cao hơn hẳn những người khác trong tháng được xếp ít ca cuối tuần
hơn ở tháng sau. Số đếm chỉ dùng để chia tải, không dùng để đánh giá ai.

### Sau một đêm bị gọi

- Người bị gọi ban đêm được bắt đầu làm muộn vào hôm sau, không cần xin.
- Một ca có hơn hai lần bị gọi ban đêm: việc giảm các alert đó (sửa nguyên
  nhân, sửa ngưỡng, hoặc hạ xuống `ticket` theo mục "Xem lại mọi lần gọi" của
  `on-call.md`) được xếp lên đầu sprint kế tiếp, trước việc tính năng.

### Người mới vào vòng trực

Người mới không vào vòng trực ngay:

1. Một ca đi theo (shadow): nhận mọi lần gọi cùng người trực, xem người trực
   làm, không tự quyết.
2. Một ca trực chính, có một người thứ hai được chỉ định sẵn sàng giúp.
3. Sau đó vào vòng trực như mọi người.

### Từ khi nào áp dụng

Các quy tắc trên áp dụng từ ngày việc gọi người chạy thật. Hôm nay chưa có
thành phần gửi thông báo nào (`on-call.md`, mục Khoảng trống), nên lịch trực
chỉ dùng cho diễn tập.

Đền bù cho việc trực (tiền hay ngày nghỉ) do công ty và luật lao động quyết;
tài liệu này không ghi mức.

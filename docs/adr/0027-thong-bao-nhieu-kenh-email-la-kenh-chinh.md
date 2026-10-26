# 0027. Thông báo nhiều kênh, email là kênh chính

Trạng thái: Đã chấp nhận
Ngày: đề xuất giữa Sprint 24, quyết định cuối Sprint 24
Người quyết định: trưởng nhóm, cùng product owner
Hạn góp ý: hết thứ Sáu tuần thứ hai Sprint 24

Chưa xây ở stage-4: Notifications vẫn chỉ gửi email như stage-3. Thiết kế và
buổi review ở `docs/design/notification-design-review.md`.

### Bối cảnh

`docs/team/notification-requirements.md`: mỗi email ghi tên cửa hàng (TB-1),
khách chọn thêm SMS hoặc push (TB-2), không mất email về đơn (TB-3), không gửi
một SMS hai lần (TB-4). Stage-3 có một sender cho một kênh: `NotificationSender`
bỏ cuộc sau 5 lần trong khoảng 30 giây, đủ cho Mailpit nhưng không đủ khi một
dịch vụ bên ngoài sập. Cột `Channel` của `Notification` đã có, mọi dòng ở
stage-3 là `email`.

### Các phương án

- Một vòng gửi cho mọi kênh: ít code, nhưng một nhà cung cấp chậm làm chậm mọi
  kênh khác, và mọi kênh cùng một cách thử lại.
- API, hay từng service, gọi thẳng nhà cung cấp: trái ADR 0002 (mọi service báo
  tin cùng một cách; nhà cung cấp chậm không nằm trong process nhận đơn).
- Mỗi kênh một sender trong Notifications, mỗi sender có batch, thử lại và nhịp
  riêng; email gửi ít nhất một lần, SMS và push gửi nhiều nhất một lần.
- Như trên, nhưng SMS cũng gửi ít nhất một lần: không mất SMS, nhưng một lần
  dừng giữa chừng là một SMS trả tiền hai lần (trái TB-4).

### Quyết định

Chọn phương án thứ ba.

- Consumer lưu một dòng cho mỗi kênh khách đã chọn, cùng transaction với dòng
  inbox, như stage-3 lưu dòng email.
- Mỗi kênh có sender riêng: batch, thử lại và nhịp riêng, một bulkhead giữa
  các kênh. Mỗi sender gọi nhà cung cấp qua một interface của kênh đó, như
  `IEmailSender`.
- Thử lại trong 24 giờ (giả định), không còn 30 giây; nhịp gửi đặt theo tốc độ
  nhà cung cấp cho phép, để hàng chờ sau một lần sập được gửi hết mà không bị
  từ chối.
- Email: ít nhất một lần, luôn được gửi cho mọi tin về đơn. Email là kênh chính.
- SMS và push: nhiều nhất một lần. Dòng được đánh dấu trước khi gọi nhà cung
  cấp; lỗi không rõ đã gửi hay chưa thì không gửi lại.
- Notifications là chủ của lựa chọn kênh của khách (notification preferences).
- Tên cửa hàng lấy theo `shopId` mà message mang từ release 2 của
  `multi-shop-data-rollout.md`.

### Hệ quả

- Mất một SMS khi Notifications dừng giữa chừng là chấp nhận được, chỉ vì cùng
  tin đó luôn có email. Bỏ email khỏi một loại tin là phải xem lại ADR này.
- Notifications cần bản sao tên cửa hàng theo `shopId` (chủ là `shops` của
  Ordering); dòng đó vào `data-ownership.md` khi xây.
- Push chờ bản app cho điện thoại (ADR 0017).
- Thêm một nhà cung cấp SMS và một dịch vụ push phải chọn, theo cách của ADR
  0024; ADR này không chọn nhà cung cấp.

Đội xem lại quyết định khi: một loại tin cần SMS mà không có email; nhà cung
cấp SMS nhận khóa chống gửi trùng (lúc đó SMS gửi ít nhất một lần được); thử
lại 24 giờ không đủ cho một lần sập của dịch vụ email.

### Ý kiến đã nhận

Tester hỏi khách chỉ chọn SMS, không muốn email, thì sao. Không cho chọn: email
luôn gửi, vì đó là điều làm SMS nhiều nhất một lần an toàn. Product owner đồng
ý; quyết định không đổi.

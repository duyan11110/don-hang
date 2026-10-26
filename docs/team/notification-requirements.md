# Yêu cầu: thông báo cho khách của 1.000 cửa hàng

Bước 1 của `docs/design/system-design-method.md` cho bài toán thông báo. Bản
nháp của product owner và đội Đơn Hàng. Mọi con số ghi "giả định" là giả định
của đội, chưa phải số đo. Thiết kế trả lời ở
`docs/design/notification-design-review.md`.

### Xuất phát: stage-3 đang chạy gì

- API ghi message `order.*` vào outbox cùng transaction với đơn; relay đưa lên
  RabbitMQ (ADR 0002).
- `OrderEventsConsumer` của Notifications biến mỗi message thành một dòng email
  trong `notifications` (`donhang_notifications`), cùng transaction với dòng
  inbox.
- `NotificationSender` mỗi 2 giây nhận tối đa 10 dòng đến hạn và gửi qua
  `IEmailSender` (MailKit, SMTP). Gửi lỗi thì thử lại sau 2, 4, 8, 16 giây;
  lần lỗi thứ 5 là cuối, dòng thành `failed`.
- ADR 0024 chuyển việc gửi sang Dịch vụ A, một dịch vụ gửi email bên ngoài;
  lab vẫn dùng Mailpit.

### Nhu cầu mới

- TB-1: Mỗi email ghi tên cửa hàng mà khách đã mua.
- TB-2: Khách chọn nhận thêm SMS hoặc push notification cho một số sự kiện của
  đơn (giao hàng, hoàn tiền xong).
- TB-3: Email về đơn không bao giờ mất, kể cả khi dịch vụ gửi email lỗi vài
  giờ.
- TB-4: Một SMS đã trả tiền không được gửi hai lần.

Push notification là tin do hệ điều hành của điện thoại hiện cho một app đã
cài, gửi qua dịch vụ push của hãng làm nền tảng. App Đơn Hàng chưa có bản cho
điện thoại ở stage-4 (ADR 0017), nên push chờ bản đó.

### Phạm vi

- Trong phạm vi: tin về đơn của chính một khách (đặt, giao, hủy, hoàn tiền).
- Ngoài phạm vi: tin gửi cho nhiều khách cùng lúc (khuyến mãi). Loại tin đó
  cần quy tắc đồng ý nhận tin riêng và lượng gửi lớn hơn nhiều, nên là một bài
  toán khác.

### Ước lượng

| Đầu vào | Giá trị |
|---|---|
| Đơn mỗi giây, giờ đông nhất | Khoảng 3,3 (`capacity-plan.md`) |
| Email mỗi đơn | 2: đặt đơn, giao hàng (giả định) |
| Email mỗi giây, giờ đông nhất | Khoảng 6,6, nếu cả hai rơi vào giờ đó |
| Email mỗi giây, trung bình ngày thường | Khoảng 1,2 (50.000 đơn × 2 / 86.400 giây) |
| Trần của sender, mỗi bản Notifications | 10 dòng mỗi 2 giây, tức 5 email mỗi giây |
| Tốc độ Dịch vụ A cho phép | 10 email mỗi giây (giả định, chờ hợp đồng) |
| Khách chọn thêm SMS | 20% số đơn (giả định) |

Một bản Notifications không theo kịp giờ đông nhất (6,6 so với 5 mỗi giây):
hàng chờ tăng khoảng 1,6 email mỗi giây trong giờ đó. Hai bản theo kịp, vì
sender nhận dòng bằng `FOR UPDATE SKIP LOCKED`, và vẫn dưới tốc độ Dịch vụ A
cho phép. SMS ở giờ đông khoảng 0,7 mỗi giây: lượng nhỏ, nhưng mỗi tin có giá.

### Driver xếp hạng

1. Không mất email nào về đơn (TB-3).
2. Email tới trong vài phút (giả định) kể từ khi đơn đổi trạng thái.
3. Ngày đông của một cửa hàng không làm chậm email của các cửa hàng khác.
4. Một SMS đã trả tiền không gửi hai lần (TB-4).

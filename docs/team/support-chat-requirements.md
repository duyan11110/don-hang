# Yêu cầu: chat hỗ trợ giữa khách và cửa hàng

Bước 1 của `docs/design/system-design-method.md` cho bài toán chat hỗ trợ. Bản
nháp của product owner và đội Đơn Hàng. Mọi con số ghi "giả định" là giả định
của đội, chưa phải số đo. Thiết kế trả lời ở
`docs/design/support-chat-design-review.md`.

### Xuất phát

- Mọi màn hình của `DonHang.App` chỉ hiện thứ đã tải: `orderProvider`
  (`features/ordering/orders_api.dart`) tải một đơn một lần, và chỉ tải lại khi
  khách đăng nhập đổi.
- App không có timer hỏi lại API. Chú thích của
  `features/ordering/queue_sync.dart` ghi: "There is no timer and no backoff".
- Khách và cửa hàng hôm nay chỉ liên lạc qua email của Notifications.
- Chat cần thứ hệ thống chưa có: server gửi một tin mới tới một màn hình đang
  mở, mà màn hình đó không phải hỏi.

### Phạm vi

- Trong phạm vi: chat giữa một khách và nhân viên của cửa hàng khách đã mua, có
  thể gắn với một đơn.
- Ngoài phạm vi: chat giữa các khách với nhau, bot trả lời tự động, gửi file.

### Kịch bản

| Số | Tình huống | Phản hồi | Đo |
|---|---|---|---|
| CT-1 | Một bên gửi tin khi bên kia đang mở màn hình chat | Tin hiện ở bên kia | Trong 2 giây (giả định) |
| CT-2 | Nhân viên cửa hàng A mở danh sách chat | Chỉ cuộc trò chuyện của cửa hàng A | Không cuộc nào của cửa hàng khác |
| CT-3 | Kết nối rớt khi đang có tin tới | Không mất tin; tin hiện khi nối lại | Mọi tin đã gửi thành công đều tới |
| CT-4 | Khách xem lại cuộc trò chuyện cũ | Lịch sử còn đủ | Giữ 12 tháng (giả định) |
| CT-5 | Cửa hàng trả lời khi khách không mở màn hình chat | Khách nhận email | Sau 5 phút chưa đọc (giả định) |

CT-5 dùng email vì push notification cần bản app cho điện thoại, mà ADR 0017
chưa làm; tài liệu này không quyết lại ADR 0017.

### Ước lượng

Theo định luật Little, số cuộc trò chuyện mở cùng lúc = số cuộc bắt đầu mỗi
giây × thời gian một cuộc mở.

- 5% số đơn dẫn tới một cuộc chat (giả định): ở giờ đông khoảng 3,3 × 0,05 =
  khoảng 0,17 cuộc mỗi giây.
- Một cuộc mở trung bình 10 phút, 600 giây (giả định): khoảng 100 cuộc mở cùng
  lúc, khoảng 200 kết nối (khách và nhân viên).
- Khoảng 10 tin mỗi cuộc (giả định): khoảng 1,7 tin mỗi giây, nhỏ so với đặt
  đơn.

Tài nguyên đáng đếm là kết nối giữ mở, phần lớn thời gian không có tin, không
phải số request mỗi giây.

### Giả định và người xác nhận

| Giả định | Người xác nhận (vai trò) |
|---|---|
| 5% số đơn dẫn tới chat, mỗi cuộc mở 10 phút | Product owner, đo sau khi có |
| Giữ lịch sử 12 tháng | Product owner |
| Email sau 5 phút chưa đọc | Product owner |
| Đội Đặt hàng phụ trách chat | Trưởng nhóm (ADR 0025, giả định) |

### Driver xếp hạng

1. Tin tới màn hình đang mở trong vài giây (CT-1).
2. Không mất tin khi việc chuyển tin hỏng (CT-3).
3. Nhân viên không bao giờ thấy chat của cửa hàng khác (CT-2).
4. Chat không bao giờ lấy sức chứa mà đặt đơn cần.

# 0010. Hoàn tiền qua Cổng A

Trạng thái: Đã chấp nhận
Ngày: quyết định trong tuần đầu Sprint 15, viết lại thành ADR trong Sprint 16
Người quyết định: trưởng nhóm, cùng product owner
Hạn góp ý: không có (viết sau khi đã làm)

ADR này viết sau khi đã làm, theo ADR 0001. Tiêu chí, kết quả thử, SLA và điều
khoản hợp đồng của hai ứng viên ở `docs/team/payment-gateway-evaluation.md`;
ADR này không chép lại.

### Bối cảnh

Hoàn tiền (`docs/team/refund-requirements.md`) cần một cổng thanh toán bên
ngoài nhận lời gọi hoàn tiền. Đơn Hàng không tự chuyển tiền được, nên câu hỏi
không phải tự làm hay mua, mà mua của ai.

### Các phương án

- Cổng A.
- Cổng B.

### Quyết định

Chọn Cổng A. Cổng B bị loại vì không nhận idempotency key (tiêu chí T1, rủi ro
R2): gửi lại sau lỗi mạng có thể hoàn tiền hai lần, trái YC-9. Cổng A không
hoàn tiền được đơn chuyển khoản; các đơn đó do chăm sóc khách hàng xử lý tay.

### Hệ quả

- Chỉ `DonHang.Payments/GatewayRefundClient.cs` biết lời gọi và câu trả lời
  của Cổng A; phần còn lại của Đơn Hàng chỉ thấy ba kết quả `Refunded`,
  `Refused`, `TryAgainLater`.
- Đơn chuyển khoản bị từ chối và hiện trong danh sách của nhân viên.
- `fake-gateway/` đóng vai môi trường test của Cổng A trong lab.

### Kế hoạch rời đi

Viết ngay khi chọn, lúc đội còn biết mọi chỗ dùng cổng và còn đòi được điều
khoản hợp đồng mà kế hoạch cần.

Dấu hiệu phải rời đi:

- Cổng A không giữ cam kết khả dụng ba tháng trong sáu tháng liền.
- Cổng A báo bỏ phiên bản API đang dùng mà không có bản thay thế làm được ba
  kết quả trên.
- Giá gia hạn tăng quá mức hợp đồng cho phép.

Các bước:

1. Chọn cổng mới bằng một lần đánh giá như `payment-gateway-evaluation.md`,
   cùng tiêu chí.
2. Viết một client mới cho cổng mới, trả đúng ba kết quả mà
   `GatewayRefundClient` trả, kèm test của nó. Saga hoàn tiền,
   `RefundSender` và các service khác không đổi.
3. Xuất lịch sử hoàn tiền từ Cổng A (CSV, theo điều khoản xuất dữ liệu) và lưu
   cùng các bản sao lưu, để kế toán vẫn đối soát được sau khi hợp đồng kết
   thúc.
4. Chạy cả hai cổng trong một giai đoạn: khoản thanh toán qua Cổng A chỉ hoàn
   được qua Cổng A, nên mỗi dòng hoàn tiền phải biết khoản thanh toán của nó đi
   qua cổng nào, cho tới khi khoản cuối cùng của Cổng A hết hạn hoàn tiền (180
   ngày).
5. Hết giai đoạn đó, gỡ client cũ và cấu hình của Cổng A.

Ước lượng: 10–20 ngày công cho bước 2 tới 4, chưa tính lần đánh giá.

Phần thử được ngay, không chờ ngày phải rời đi: xuất lịch sử hoàn tiền từ môi
trường test (trong lab là `GET /v1/refunds` của `fake-gateway`), nạp vào một
bảng tạm và so số dòng, số tiền với bảng `payments` của `donhang_payments`.
Việc này được kiểm như một lần thử khôi phục, không tin là chạy được cho tới
ngày cần.

Ở stage-3 Đơn Hàng không đổi cổng và không có code chuyển cổng.

### Ý kiến đã nhận

Product owner hỏi có nên chọn Cổng B để hoàn được đơn chuyển khoản không.
Không: thiếu idempotency key là tiêu chí loại ngay, viết trước khi so ứng viên,
nên một tính năng khác không bù được.

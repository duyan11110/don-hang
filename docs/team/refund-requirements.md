# Yêu cầu: khách tự yêu cầu hoàn tiền cho đơn đã thanh toán

Bản nháp của product owner và đội Đơn Hàng, để các bên liên quan góp ý trước
Sprint 15 planning. Cách làm ở `docs/design/refund-design.md`.

## Vấn đề

Biên bản họp chặn hủy đơn (`meeting-notes-example.md`) quyết định: đơn `paid`
không hủy được từ ứng dụng, khách phải yêu cầu hoàn tiền. Hôm nay khách chỉ làm
được việc đó bằng cách gọi chăm sóc khách hàng. Nhân viên hoàn tiền bằng tay
trên trang quản trị của cổng thanh toán rồi báo kế toán qua email. Khách phải
chờ một cuộc gọi, chăm sóc khách hàng mất thời gian, kế toán đối soát từ email.

## Mục tiêu

1. Khách tự yêu cầu hoàn tiền cho đơn đã thanh toán, không cần gọi điện.
2. Kế toán đối soát được mỗi khoản hoàn tiền mà không phải hỏi lại ai.

## Ngoài phạm vi

- Hoàn một phần số tiền của đơn.
- Đơn `shipped`, kể cả đơn khách từ chối nhận: đó là câu hỏi còn mở từ biên bản
  họp, bộ phận vận hành trả lời.
- Đơn thanh toán khi nhận hàng.
- Nhân viên tạo yêu cầu hoàn tiền thay khách.

## Yêu cầu chức năng

- YC-1: Khách đã đăng nhập yêu cầu hoàn tiền được cho đơn của chính mình khi
  đơn ở trạng thái `paid`.
- YC-2: Khách không yêu cầu hoàn tiền được cho đơn của người khác; hệ thống từ
  chối và không thay đổi gì.
- YC-3: Số tiền hoàn bằng toàn bộ số tiền khách đã thanh toán cho đơn.
- YC-4: Sau khi gửi yêu cầu, khách thấy đơn đang hoàn tiền và không gửi được
  yêu cầu thứ hai cho cùng đơn.
- YC-5: Khi cổng thanh toán xác nhận đã hoàn tiền, đơn chuyển sang `cancelled`
  và khách nhận một email báo đã hoàn tiền.
- YC-6: Khi cổng thanh toán từ chối, nhân viên thấy yêu cầu đó trong danh sách
  cần xử lý, kèm lý do cổng trả về.

## Yêu cầu phi chức năng

- YC-7: Yêu cầu hoàn tiền của khách được nhận và trả lời trong 2 giây, kể cả
  khi cổng thanh toán không trả lời hoặc báo lỗi.
- YC-8: Mỗi yêu cầu hoàn tiền lưu người yêu cầu và thời điểm yêu cầu; hai thông
  tin này không bị sửa hay xóa về sau, để kế toán đối soát.
- YC-9: Một đơn không bao giờ được hoàn tiền hai lần, kể cả khi việc gửi sang
  cổng thanh toán phải thử lại.
- YC-10: Khi cổng thanh toán lỗi, yêu cầu được gửi lại tự động trong ít nhất 24
  giờ trước khi chuyển cho nhân viên xử lý.

## Câu hỏi mở

| Câu hỏi | Ai trả lời | Hạn |
|---|---|---|
| Cổng thanh toán cho hoàn tiền tối đa bao nhiêu ngày sau khi thanh toán? | Bên cung cấp cổng thanh toán, product owner hỏi | Tuần đầu Sprint 15 |
| Đơn chuyển khoản ngân hàng có hoàn qua cổng thanh toán được không? | Bên cung cấp cổng thanh toán, product owner hỏi | Tuần đầu Sprint 15 |
| Kế toán cần danh sách hoàn tiền dạng nào, bao lâu một lần? | Kế toán | Cuối Sprint 15 |
| Ai bên chăm sóc khách hàng nhận các yêu cầu bị cổng từ chối? | Trưởng nhóm chăm sóc khách hàng | Trước Sprint 16 |

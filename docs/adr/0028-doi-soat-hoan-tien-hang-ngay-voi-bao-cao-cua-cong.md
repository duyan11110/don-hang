# 0028. Đối soát hoàn tiền mỗi ngày với báo cáo của cổng

Trạng thái: Đã chấp nhận
Ngày: đề xuất đầu Sprint 25, quyết định cuối tuần đầu Sprint 25
Người quyết định: trưởng nhóm, cùng kế toán
Hạn góp ý: hết thứ Sáu tuần đầu Sprint 25

Chưa xây ở stage-4: không có code đối soát trong repo. Thiết kế và buổi review
ở `docs/design/reconciliation-design-review.md`.

### Bối cảnh

`docs/team/reconciliation-requirements.md`: mọi chỗ lệch giữa dòng hoàn tiền
của Payments và báo cáo của Cổng A được giải thích, phát hiện trong một ngày,
và chỉ người sửa dòng tiền. Khoảng 1.000 khoản hoàn mỗi ngày đông nhất (giả
định). Bảng `payments` không giữ id hoàn tiền của cổng; mỗi lời gọi mang
idempotency key `refund-<id của dòng>` (`GatewayRefundClient.cs`), và
`GET /v1/refunds` của `fake-gateway` trả key đó cho mỗi khoản.

### Các phương án

- Mỗi ngày một lần, so với báo cáo của cổng: một job, một lần lấy báo cáo;
  bắt được cả khoản hoàn làm ngoài Đơn Hàng. Một chỗ lệch có thể nằm im tới
  một ngày.
- Hỏi cổng về từng khoản ngay sau khi gửi: tìm câu trả lời bị lạc sớm hơn,
  nhưng thêm một lời gọi cho mỗi khoản và không thấy khoản hoàn làm ngoài Đơn
  Hàng, nên không thay được báo cáo.
- Chỉ tin câu trả lời của cổng cho từng lời gọi, như stage-3: không thêm gì,
  nhưng không có bản ghi thứ hai để so, trái mục tiêu 2 của
  `refund-requirements.md`.

### Quyết định

Chọn phương án thứ nhất, trong Payments, chủ của dòng hoàn tiền và của khóa
cổng.

- Mỗi ngày một job lấy báo cáo của ngày trước qua API của cổng và lưu từng
  dòng báo cáo vào database của Payments.
- Mỗi dòng báo cáo được ghép với một dòng hoàn tiền theo key `refund-<id>`.
- Mỗi lần so cho một trong năm kết quả: khớp; cổng đã hoàn nhưng dòng là
  `failed`; cổng có khoản hoàn không có dòng; dòng `refunded` không có trong
  báo cáo; số tiền khác.
- Dòng `refunded` không có trong báo cáo chỉ thành chỗ lệch sau thêm một lần
  chạy (giả định), vì khoản hoàn gần cuối ngày có thể chỉ có trong báo cáo hôm
  sau.
- Job không sửa dòng hoàn tiền nào. Mỗi chỗ lệch vào một danh sách cho nhân
  viên; sửa là một thay đổi mới do người làm và ghi vào nhật ký kiểm toán theo
  `docs/design/audit-log.md`. Nhân viên đề xuất, kế toán duyệt (vai trò giả
  định).
- Báo cáo trễ hay cổng lỗi lúc chạy: job chạy lại; ngày bị lỡ được báo cho kế
  toán (giả định).
- Dòng báo cáo và kết quả mỗi lần chạy được giữ bằng thời gian giữ dòng hoàn
  tiền (giả định).

### Hệ quả

- Payments có thêm một job, một bảng dòng báo cáo và một bảng kết quả; dòng
  báo cáo có chủ là Payments (`data-ownership.md`).
- Kế toán nhận danh sách chỗ lệch mỗi sáng, không đối soát từ email.
- Một chỗ lệch có thể nằm im tới một ngày.

Đội xem lại quyết định khi: thêm cổng thứ hai theo bước 4 kế hoạch rời đi của
ADR 0010 (mỗi dòng phải biết cổng của nó, mỗi cổng một báo cáo); số khoản hoàn
mỗi ngày vượt xa một lô nhỏ.

### Ý kiến đã nhận

Kế toán hỏi job có thể tự sửa các chỗ lệch rõ ràng không. Không: sửa dòng tiền
do người làm, người khác duyệt, để không ai vừa làm vừa duyệt một thay đổi về
tiền. Quyết định không đổi.

# Yêu cầu: đối soát hoàn tiền với cổng thanh toán

Bước 1 của `docs/design/system-design-method.md` cho bài toán thanh toán và đối
soát. Bản nháp của product owner, kế toán và đội Đơn Hàng. Mọi con số ghi "giả
định" là giả định của đội, chưa phải số đo. Thiết kế trả lời ở
`docs/design/reconciliation-design-review.md`.

### Xuất phát

Saga hoàn tiền của stage-3 (`refund-design.md`, ADR 0003) giữ dữ liệu của chính
Đơn Hàng khớp nhau: đơn, dòng hoàn tiền trong `donhang_payments`, email. Nó
không bao giờ so các dòng đó với những gì Cổng A đã thực sự làm. Mục tiêu 2 của
`refund-requirements.md` (kế toán đối soát được mỗi khoản hoàn tiền) cần việc
so đó.

Đối soát là so hai bản ghi độc lập của cùng một khoản tiền, ở đây dòng hoàn
tiền của Payments và báo cáo của cổng, rồi giải thích mọi dòng hai bên khác
nhau. Báo cáo của cổng là lịch sử hoàn tiền Cổng A cho xuất dạng CSV mọi lúc,
qua trang quản trị và qua API (T7 của `payment-gateway-evaluation.md`); trong
lab, `GET /v1/refunds` của `fake-gateway` đóng vai báo cáo đó.

### Phạm vi

- Trong phạm vi: các khoản hoàn tiền qua Cổng A.
- Ngoài phạm vi: thu tiền (Payments không có luồng thu tiền); các khoản hoàn
  tay ngoài cổng, như đơn chuyển khoản (ADR 0010) và yêu cầu bị cổng từ chối
  mà chăm sóc khách hàng xử lý (R4 của `risk-register-example.md`).

Câu hỏi mở "kế toán cần danh sách hoàn tiền dạng nào, bao lâu một lần" của
`refund-requirements.md` được trả lời ở đây: đối soát mỗi ngày một lần, kết quả
có trước sáng ngày làm việc kế tiếp (giả định, kế toán xác nhận). File
`refund-requirements.md` không sửa.

### Kịch bản

| Số | Tình huống | Phản hồi | Đo |
|---|---|---|---|
| ĐS-1 | Cổng đã hoàn tiền, nhưng dòng của Payments là `failed` (câu trả lời bị lạc) | Hiện thành một chỗ lệch cho nhân viên | Phát hiện trong lần chạy kế tiếp, tức trong một ngày |
| ĐS-2 | Cổng có khoản hoàn không có dòng nào trong Payments (ví dụ hoàn tay trên trang quản trị của cổng) | Hiện thành một chỗ lệch | Như trên |
| ĐS-3 | Dòng `refunded` của Payments không có trong báo cáo | Hiện thành một chỗ lệch, sau thêm một lần chạy | Trong hai ngày |
| ĐS-4 | Hai bên cùng có khoản hoàn nhưng số tiền khác | Hiện thành một chỗ lệch | Trong một ngày |

Mọi chỗ lệch được nhân viên giải thích; không chỗ nào tự biến mất.

### Ước lượng

- Theo ví dụ của `system-design-method.md`: 1% số đơn bị yêu cầu hoàn tiền
  (giả định), khoảng 500 khoản mỗi ngày thường, khoảng 1.000 trong ngày đông
  nhất.
- Một lần chạy mỗi ngày so khoảng 1.000 dòng mỗi bên: một lô nhỏ. Tải không
  định hình thiết kế.

### Giả định và người xác nhận

| Giả định | Người xác nhận (vai trò) |
|---|---|
| Báo cáo của Cổng A ghi idempotency key của mỗi khoản (như `GET /v1/refunds` của lab) | Lập trình viên làm tích hợp cổng |
| Một lần mỗi ngày, kết quả trước sáng ngày làm việc kế tiếp, là đủ | Kế toán |
| Một khoản hoàn gần cuối ngày có thể chỉ có trong báo cáo của ngày sau | Lập trình viên làm tích hợp cổng |

### Driver xếp hạng

1. Mọi chỗ lệch được giải thích.
2. Mỗi chỗ lệch được phát hiện trong một ngày.
3. Chỉ người sửa dòng tiền; không job nào tự sửa.

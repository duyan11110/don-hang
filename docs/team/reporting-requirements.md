# Yêu cầu: báo cáo cho cửa hàng và cho đội Đơn Hàng

Bước 1 của `docs/design/system-design-method.md` cho bài toán báo cáo. Bản
nháp của product owner và đội Đơn Hàng. Mọi con số ghi "giả định" là giả định
của đội, chưa phải số đo. Thiết kế trả lời ở
`docs/design/reporting-design-review.md`.

### Xuất phát

- Stage-3 không có báo cáo nào ngoài các file `db/queries/*.sql` của bài SQL.
- Truy vấn báo cáo biến nhiều dòng thành vài con số về một khoảng thời gian,
  như doanh thu mỗi ngày; đặt đơn chỉ đọc và ghi vài dòng của một đơn.
- Từ stage-3, thanh toán và hoàn tiền nằm ở `donhang_payments`, đơn ở
  `donhang`. Một truy vấn PostgreSQL thường chỉ đọc database mà kết nối của nó
  đã mở, nên doanh thu như `revenue-by-customer.sql` không còn là một truy vấn:
  file đó chỉ còn chạy vì bảng `payments` cũ chưa xóa trong `donhang`, một bản
  chép không ai cập nhật từ lúc tách (ADR 0008).
- `multi-shop-design-review.md` để mở câu hỏi: báo cáo gộp mọi cửa hàng đọc thế
  nào khi một cửa hàng có database riêng (ADR 0026).
- `capacity-plan.md` giữ mọi lần đọc ở primary.

### Người đọc

- Nhân viên một cửa hàng: chỉ thấy số của cửa hàng mình.
- Đội Đơn Hàng: xem mọi cửa hàng, kể cả cửa hàng có database riêng.

### Kịch bản

| Số | Tình huống | Phản hồi | Đo |
|---|---|---|---|
| BC-1 | Nhân viên xem doanh thu, số đơn, số tiền hoàn theo ngày của cửa hàng mình | Bảng theo ngày, kèm thời điểm chốt số | Số cũ nhiều nhất 2 giờ (giả định) |
| BC-2 | Nhân viên xem sản phẩm bán chạy của cửa hàng mình trong một khoảng ngày | Danh sách sản phẩm theo số lượng bán | Như trên |
| BC-3 | Đội Đơn Hàng xem số đơn theo ngày của mọi cửa hàng | Đủ mọi cửa hàng, kể cả cửa hàng có database riêng | Không thiếu cửa hàng nào |
| BC-4 | Ai đó chạy báo cáo một năm vào giờ đông | Đặt đơn trả lời như ngày thường | Báo cáo không lấy kết nối của primary |
| BC-5 | Nhân viên cửa hàng A mở báo cáo | Chỉ số của cửa hàng A | Không con số nào của cửa hàng khác |

Một ngày tính theo giờ Việt Nam (giả định): `orders-by-day.sql` cho thấy có đơn
rơi vào hai ngày khác nhau theo UTC và theo giờ Việt Nam.

### Ước lượng

- 50.000 đơn mỗi ngày thường (`capacity-plan.md`), giữ 2 năm (giả định): khoảng
  36 triệu đơn, mỗi đơn vài dòng hàng.
- Báo cáo một năm trên dữ liệu gốc đọc hàng chục triệu dòng.
- Một truy vấn báo cáo giữ kết nối lâu hơn một lần đặt đơn hàng nghìn lần (giả
  định: vài giây so với vài mili giây).

### Giả định và người xác nhận

| Giả định | Người xác nhận (vai trò) |
|---|---|
| Số cũ nhiều nhất 2 giờ là đủ | Product owner, cùng vài cửa hàng |
| Ngày theo giờ Việt Nam | Kế toán |
| Giữ 2 năm dữ liệu cho báo cáo | Product owner, cùng kế toán |
| Đội Cửa hàng phụ trách database báo cáo | Trưởng nhóm (ADR 0025, giả định) |

### Driver xếp hạng

1. Báo cáo không bao giờ lấy sức chứa mà đặt đơn cần (BC-4).
2. Mỗi cửa hàng chỉ thấy số của mình (BC-5).
3. Báo cáo gộp nhiều cửa hàng có cả cửa hàng ở database riêng (BC-3).

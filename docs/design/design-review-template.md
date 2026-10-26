# Review thiết kế: tên bài toán

Mẫu cho tài liệu đem ra buổi review thiết kế, theo năm bước của
`system-design-method.md`. Chép file này, điền từng mục, gửi trước buổi review
ít nhất hai ngày làm việc (giả định): người review đọc trước, buổi review chỉ
dành cho câu hỏi. Mỗi mục ghi bước của khung mà nó đến từ, để người review biết
một chỗ yếu bắt nguồn từ bước nào. Mọi con số giả định ghi chữ "giả định".

Trạng thái: bản nháp | đã review | đã chốt
Người đề xuất: ghi theo vai trò

### Quyết định cần review

Một hai câu: cần quyết điều gì, và đề xuất là gì. Người review đọc mục này
trước hết, nên nó đứng đầu, không nằm cuối tài liệu.

### Bối cảnh và driver (bước 1)

Trỏ tài liệu yêu cầu, không chép lại. Ghi phạm vi, những quyết định đã có mà
tài liệu này không mở lại (mỗi cái một đường dẫn), và danh sách driver xếp
hạng.

### Ước lượng và giả định (bước 2)

Các con số, mỗi số kèm giả định của nó và quyết định mà nó phục vụ. Ghi giả
định nào có người xác nhận, theo vai trò.

### Sơ đồ tổng thể (bước 3)

Một sơ đồ, và đường đi của từng thao tác chính qua sơ đồ, kể cả khi một phần
hỏng. Mỗi kho ghi chủ theo `data-ownership.md`.

### Đi sâu (bước 4)

Một đến ba phần, mỗi phần trả lời: dữ liệu nó sở hữu, nhất quán mỗi thao tác
cần, làm gì khi từng phụ thuộc hỏng, lớn lên theo tải ra sao.

### Nút cổ chai và điểm hỏng đơn lẻ (bước 5)

Phần giới hạn trước và phần kế tiếp, ở tải nào. Với mỗi điểm hỏng đơn lẻ: thao
tác nào dừng, chờ hay chạy ở mức giảm.

### Phương án bị loại và điểm đánh đổi (bước 3 và 4)

Mỗi phương án bị loại kèm driver làm nó bị loại. Mỗi điểm đánh đổi ghi thuộc
tính chất lượng được lợi, thuộc tính bị thiệt và driver đã quyết; điểm nhạy
ghi riêng.

### Rủi ro và câu hỏi mở

| Rủi ro hoặc câu hỏi | Ai trả lời (vai trò) | Hạn hoặc bước tiếp theo |
|---|---|---|

### ADR sẽ viết

Phần nào của thiết kế tốn kém nếu phải đảo ngược, cần một ADR; số ADR khi đã
có.

### Câu hỏi phản biện trong buổi review

Ghi lại trong buổi review, ngay vào tài liệu này.

| Câu hỏi | Trả lời, trỏ driver, ADR hoặc rủi ro | Việc tiếp theo | Người phụ trách (vai trò) |
|---|---|---|---|

Câu nào chưa trả lời được thì ghi "mở", kèm người phụ trách và việc tiếp theo,
không trả lời bằng một cách sửa nghĩ ra tại chỗ.

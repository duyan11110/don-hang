# Postmortem NNNN: [tên ngắn của sự cố, theo điều khách gặp]

Trạng thái: nháp | đã xem lại | đóng (mọi action item xong)
Mức: SEV1 | SEV2 | SEV3
Người viết: [vai trò, không tên người]
Ngày xem lại cùng đội: [ngày]

Postmortem mô tả điều hệ thống và quy trình đã cho phép xảy ra, không mô tả ai
làm sai. Người sợ bị đổ lỗi sẽ giấu điều họ biết, và lần sau đội học được ít
hơn. Viết "commit đổi cấu hình đi thẳng vào Deployment", không viết "X đã đổi
cấu hình".

### Tóm tắt

Hai hay ba câu: khách gặp gì, bao lâu, đội giảm thiểu bằng cách nào.

### Ảnh hưởng

- Khách và cửa hàng gặp gì, bao nhiêu request hay đơn bị ảnh hưởng.
- Thời gian: từ lúc khách bắt đầu gặp lỗi tới lúc giảm thiểu xong.
- Error budget đã tiêu: số request xấu, và phần trăm budget 28 ngày của mỗi SLI
  bị chạm (`docs/design/slo.md`). Hơn một phần tư budget của một SLI là lý do
  postmortem này bắt buộc.

### Dòng thời gian

Từ dòng thời gian ghi trong lúc xử lý (`docs/team/incident-response.md`). Mốc
tương đối tính từ thay đổi gây sự cố (T+0) hoặc giờ thật, mỗi dòng một điều thấy
được, quyết định hay việc làm.

| Mốc | Điều xảy ra |
|---|---|
| T+0 | |

### Yếu tố góp phần

Thường có nhiều yếu tố, không một nguyên nhân gốc. Với mỗi yếu tố: hệ thống hay
quy trình đã cho phép điều gì, và vì sao điều đó hợp lý với người làm lúc đó.

### Điều đã giúp

Những gì làm sự cố ngắn hơn hay nhỏ hơn, để giữ chúng.

### Điều làm chậm

Những gì làm phát hiện hay giảm thiểu chậm hơn.

### Action item

Mỗi việc có người phụ trách theo vai trò, hạn và trạng thái; đội theo dõi chúng
như mọi việc khác trong backlog. Postmortem chỉ đóng khi mọi action item xong.

| Việc | Loại (ngăn, phát hiện, giảm thiểu) | Người phụ trách | Hạn | Trạng thái |
|---|---|---|---|---|
| | | | | mở |

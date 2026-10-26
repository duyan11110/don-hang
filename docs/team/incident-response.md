# Xử lý sự cố ở Đơn Hàng

Trạng thái: dùng từ stage-4; đã diễn tập trên staging bằng
`scripts/devops/incident-drill.sh`. Sự cố là khi dịch vụ khách nhận được mất
hay kém đi ngoài kế hoạch. Tài liệu ghi mức nghiêm trọng, ai làm gì trong lúc
xử lý, cách báo cho cửa hàng, và khi nào sự cố kết thúc. Mọi thời gian ở đây là
giả định.

### Mức nghiêm trọng

Mức đặt theo ảnh hưởng tới khách, không theo nguyên nhân. Người trực đặt mức
khi xác nhận lần gọi, và đổi mức khi ảnh hưởng đổi.

| Mức | Khi nào | Gọi ai | Cập nhật cho cửa hàng |
|---|---|---|---|
| SEV1 | Đặt đơn lỗi cho mọi cửa hàng (S1 gần như toàn bộ xấu) | Người trực, trưởng nhóm ngay; product owner để báo cửa hàng | 30 phút một lần |
| SEV2 | Một alert `severity: page` của S2, S3 hay S4 đang firing, hoặc của S1 khi chỉ một phần đơn lỗi | Người trực; thêm người khi cần (`on-call.md`) | 60 phút một lần, khi khách thấy được |
| SEV3 | Một alert `severity: ticket`: budget rò chậm, chưa ai gọi | Không gọi ai; việc trong giờ làm việc | Không gửi |

### Vai trò

- Người chỉ huy sự cố: điều phối. Quyết định thử gì tiếp và ai làm, giữ dòng
  thời gian, gọi thêm người. Người chỉ huy không tự gỡ lỗi; ai vừa chỉ huy vừa
  gỡ lỗi sẽ mất cái nhìn chung.
- Người xử lý: làm theo runbook và theo việc người chỉ huy giao: xác nhận
  alert, revert, xem dashboard và log.
- Người liên lạc: viết cập nhật cho cửa hàng theo mẫu dưới đây, gửi qua product
  owner, trả lời câu hỏi từ ngoài đội để người xử lý không bị cắt ngang.

Người trực giữ vai trò chỉ huy từ lúc xác nhận lần gọi tới khi bàn giao rõ cho
người khác ("từ giờ anh chỉ huy"). Một người quyết định thì hai người không làm
hai thay đổi trái nhau, như một người revert commit trong khi người kia sửa tay
cùng Deployment đó.

Với đội bốn lập trình viên, SEV2 thường chỉ có một người: người trực gộp cả ba
vai trò. Khi có người thứ hai, tách vai trò chỉ huy ra trước. SEV1 luôn tách ít
nhất người chỉ huy và người xử lý; trưởng nhóm hoặc product owner nhận vai trò
liên lạc.

### Cập nhật cho cửa hàng

Mỗi cập nhật nói bằng lời của cửa hàng, có ba phần, và không đoán nguyên nhân:

> Từ [giờ bắt đầu], [điều cửa hàng và khách đang gặp, ví dụ: một phần lượt xem
> danh sách sản phẩm báo lỗi]. Chúng tôi đang [việc đang làm, ví dụ: đưa cấu
> hình về bản trước]. Cập nhật tiếp theo lúc [giờ], sớm hơn nếu có thay đổi.

Nguyên nhân chỉ được nói sau khi đã chắc, thường là trong postmortem. Một
nguyên nhân đoán sai, đã gửi đi, phải rút lại và làm mất lòng tin. Cách viết cập
nhật cho các bên nói chung: `stakeholder-update-example.md`.

### Dòng thời gian

Người chỉ huy (hoặc người được giao) ghi dòng thời gian trong lúc xử lý: điều
gì thấy được, quyết định gì, ai làm gì, mỗi dòng có giờ. Ví dụ:

```
10:02 ProductReadsFastBurn firing; người trực xác nhận, SEV2
10:05 503 của đọc sản phẩm; commit 10 phút trước đổi cấu hình api ở envs/staging
10:07 revert commit đó (runbook bước 1)
10:15 alert hết; tỉ lệ xấu 5 phút dưới ngưỡng
```

Trí nhớ sau sự cố thiếu và sai thứ tự; postmortem được viết từ dòng thời gian
này.

### Kết thúc sự cố

Sự cố kết thúc khi alert đã hết và SLI giữ tốt trong 30 phút (giả định) với
cách giảm thiểu đang áp dụng, không phải khi đã biết nguyên nhân. Người chỉ huy
tuyên bố kết thúc, người liên lạc gửi cập nhật cuối.

Sau đó: sự cố tiêu hơn một phần tư budget của một SLI phải có postmortem
(`docs/design/slo.md`), viết theo `docs/postmortems/template.md` trong năm ngày
làm việc. Sự cố nhỏ hơn cũng được viết nếu đội thấy có điều đáng học.

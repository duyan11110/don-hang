# Yêu cầu: cửa hàng tự mở, tự cấu hình và rời nền tảng

Bước 1 của `docs/design/system-design-method.md` cho bài toán nền tảng SaaS
nhiều cửa hàng. Bản nháp của product owner và đội Đơn Hàng. Mọi con số ghi
"giả định" là giả định của đội, chưa phải số đo. Tài liệu không nêu giá hay
quy định pháp lý nào. Thiết kế trả lời ở
`docs/design/saas-platform-design-review.md`.

### Xuất phát

Các quyết định đã có, tài liệu này không mở lại: một bản triển khai chung (ADR
0012), bảng chung có `shop_id` (ADR 0013), giới hạn tải theo cửa hàng (ADR
0016), cửa hàng lớn sang database riêng (ADR 0026).

Còn để mở là đường đi của chính cửa hàng. Theo ADR 0013, mở cửa hàng là thêm
một dòng vào `shops`, nhưng chưa ai quy định ai thêm dòng đó, cửa hàng cấu hình
được gì, cửa hàng ở gói nào, và rời đi thế nào. CH-4 của
`multi-shop-requirements.md` (cấu hình riêng từng cửa hàng, đổi không cần
deploy) chưa có thiết kế.

### Kịch bản

| Số | Tình huống | Phản hồi | Đo |
|---|---|---|---|
| SA-1 | Một cửa hàng mới tự đăng ký | Cửa hàng mở, nhận được đơn đầu tiên | Trong 10 phút (giả định); không ai ở Đơn Hàng phải làm gì |
| SA-2 | Cửa hàng đặt tên và chọn brand | Tên và brand hiện trên app của khách | Không cần deploy |
| SA-3 | Cửa hàng tự đổi gói | Trần và tính năng của gói mới có hiệu lực | Trong vài phút (giả định) |
| SA-4 | Cửa hàng rời nền tảng | Nhận bản xuất dữ liệu của mình; dòng bị xóa sau thời gian chờ | Xóa sau 30 ngày chờ (giả định); bản trong backup hết khi backup hết hạn giữ |
| SA-5 | Cửa hàng A đổi cài đặt | Không cửa hàng nào khác thấy thay đổi | Không cài đặt nào lọt sang cửa hàng khác |

### Ước lượng

- Vài cửa hàng đăng ký mỗi ngày (giả định 5): mở cửa hàng là bài toán đúng
  sai, không phải bài toán tải.
- Chi phí là driver tăng theo số cửa hàng: node, database và platform phục vụ
  mọi cửa hàng. Giá mỗi gói phải trả được phần chi phí của các cửa hàng trong
  gói đó (giả định, không số tiền); cách chia ở `docs/design/cost-per-shop.md`.

### Giả định và người xác nhận

| Giả định | Người xác nhận (vai trò) |
|---|---|
| Đăng ký tới đơn đầu tiên trong 10 phút | Product owner |
| Thời gian chờ 30 ngày trước khi xóa | Product owner, cùng bộ phận pháp chế |
| Khoảng 5 đăng ký mỗi ngày | Product owner, bộ phận kinh doanh |
| Đội Cửa hàng phụ trách mở cửa hàng và gói | Trưởng nhóm (ADR 0025, giả định) |

### Driver xếp hạng

1. Cửa hàng mở mà không ai ở Đơn Hàng phải làm gì (SA-1).
2. Không cài đặt của cửa hàng nào lọt sang cửa hàng khác (SA-5).
3. Biết chi phí mỗi cửa hàng của từng gói.
4. Dữ liệu của cửa hàng rời đi hết vào một ngày đã nói (SA-4).

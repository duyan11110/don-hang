# Yêu cầu: phần đa cửa hàng còn để mở

Bước 1 của `docs/design/system-design-method.md` cho bài toán đa cửa hàng. Bản
nháp của product owner và đội Đơn Hàng. Mọi con số ghi "giả định" là giả định
của đội, chưa phải số đo. Thiết kế trả lời ở
`docs/design/multi-shop-design-review.md`.

### Phạm vi

Bài toán không bắt đầu từ trang trắng. Các quyết định dưới đây đã có; tài liệu
này không mở lại chúng:

- Một bản triển khai chung cho mọi cửa hàng: ADR 0012.
- Dữ liệu mọi cửa hàng trong bảng chung, có `shop_id` và row-level security:
  ADR 0013.
- Giới hạn tải theo cửa hàng, chồng lên giới hạn chung: ADR 0016.
- Thứ tự đưa `shop_id` vào dữ liệu qua ba lần phát hành:
  `docs/design/multi-shop-data-rollout.md`.

Còn để mở hai điều, cả hai nằm trong điều kiện xem lại của ADR 0013: một cửa
hàng quá lớn so với bảng chung, và khôi phục riêng một cửa hàng mà không đưa
các cửa hàng khác về quá khứ. CH-1 tới CH-4 ở `multi-shop-requirements.md`
vẫn giữ; hai kịch bản mới đánh số tiếp từ CH-5.

### CH-5: chuyển một cửa hàng lớn

| Phần | Nội dung |
|---|---|
| Nguồn | Đội vận hành, khi một cửa hàng chạm điều kiện chuyển |
| Tác nhân | Chuyển dữ liệu của cửa hàng đó ra khỏi bảng chung |
| Môi trường | Giờ thấp điểm, hệ thống đang chạy cho mọi cửa hàng |
| Phản hồi | Cửa hàng đang chuyển dừng nhận ghi trong một khoảng có giới hạn; các cửa hàng khác không thấy thay đổi |
| Đo | Cửa hàng chuyển dừng ghi tối đa 15 phút (giả định), đọc vẫn chạy; các cửa hàng khác không có request bị từ chối hay chậm hơn ngày thường |

### CH-6: khôi phục riêng một cửa hàng

| Phần | Nội dung |
|---|---|
| Nguồn | Nhân viên của một cửa hàng xóa nhầm dữ liệu, hoặc một lỗi chỉ chạm một cửa hàng |
| Tác nhân | Yêu cầu đưa dữ liệu của cửa hàng đó về một thời điểm trước sự cố |
| Môi trường | Hệ thống đang chạy cho mọi cửa hàng |
| Phản hồi | Chỉ dữ liệu của cửa hàng đó quay về thời điểm đã chọn |
| Đo | Xong trong 4 giờ làm việc (giả định); các cửa hàng khác không mất dòng nào và không dừng |

### Ước lượng

Cỡ cửa hàng rất chênh lệch (giả định): trong 1.000 cửa hàng và 50.000 đơn mỗi
ngày thường của `capacity-plan.md`, 10 cửa hàng lớn giữ khoảng 30% số đơn,
trung bình khoảng 1.500 đơn mỗi ngày mỗi cửa hàng; 990 cửa hàng còn lại trung
bình khoảng 35 đơn mỗi ngày.

- Cửa hàng lớn nhất ở `multi-shop-requirements.md` (5.000 đơn mỗi ngày) giữ
  khoảng 10% số đơn, đúng mức `capacity-plan.md` ghi là phải lập lại kế hoạch.
- Vì vậy không cần một database cho mỗi cửa hàng trong 1.000 cửa hàng; một
  database riêng cho vài cửa hàng lớn nhất thì có thể cần.
- Mỗi đơn trong `donhang` là khoảng 8 dòng (đơn, khoảng 3 dòng hàng, khoảng 4
  dòng lịch sử trạng thái; giả định), cộng sản phẩm và khách của cửa hàng.
- Cùng đơn đó trong `donhang_notifications` là khoảng 2 dòng email (đặt đơn,
  giao hàng; giả định), không có sản phẩm hay khách; trong `donhang_payments`
  chỉ có dòng hoàn tiền, khoảng 1% số đơn (giả định).
- Kết luận: dữ liệu của mỗi cửa hàng trong `donhang_notifications` và
  `donhang_payments` nhỏ so với dữ liệu của nó trong `donhang`, và tải đọc sản
  phẩm, đặt đơn đều vào `donhang`.

### Câu hỏi chưa trả lời được, thành giả định

| Giả định | Người xác nhận (vai trò) |
|---|---|
| Cỡ cửa hàng chênh như mục Ước lượng | Product owner, từ hợp đồng đã ký |
| Cửa hàng chuyển chấp nhận dừng ghi 15 phút vào giờ thấp điểm | Product owner, cùng cửa hàng đó |
| Khôi phục riêng một cửa hàng là việc hiếm, vài lần mỗi năm | Đội vận hành |
| Không hợp đồng nào đòi một bản hệ thống riêng | Product owner, cùng bộ phận kinh doanh |

Giả định cuối sai thì đó là điều kiện xem lại của ADR 0012 (một bản riêng cho
cửa hàng đó), nằm ngoài phạm vi tài liệu này.

### Driver xếp hạng

1. Các cửa hàng khác không thấy thay đổi khi một cửa hàng chuyển (CH-5).
2. Khôi phục được riêng một cửa hàng (CH-6).
3. Tải của một cửa hàng lớn rời được khỏi bảng chung.

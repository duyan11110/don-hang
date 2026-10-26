# Yêu cầu: Đơn Hàng phục vụ 1.000 cửa hàng

Bản nháp của product owner và đội Đơn Hàng, để các bên góp ý trước khi chọn
kiến trúc (ADR 0012). Mọi con số trong tài liệu này là giả định của đội, ghi
rõ ở từng chỗ, chưa phải số đo.

### Bối cảnh

Tới stage-3, Đơn Hàng chạy cho một cửa hàng: đơn, sản phẩm và khách trong
database `donhang` không mang cửa hàng nào. Bảng có cửa hàng chỉ có trong các
file lab `db/tenancy/`. Ban lãnh đạo muốn cho các cửa hàng khác thuê Đơn Hàng:
mỗi cửa hàng có khách, sản phẩm và nhân viên của mình, trên một nền tảng
chung.

### Mục tiêu

1. Phục vụ 1.000 cửa hàng (giả định cho ba năm tới) trên một nền tảng.
2. Mở một cửa hàng mới trong ngày ký hợp đồng, không chờ đội phát hành.
3. Khách và nhân viên của mỗi cửa hàng dùng Đơn Hàng như hôm nay.

### Yêu cầu phi chức năng

- CH-1: Khách và nhân viên của một cửa hàng chỉ thấy và chỉ sửa được dữ liệu
  của cửa hàng đó: đơn, sản phẩm, khách, hoàn tiền, email.
- CH-2: Mở một cửa hàng mới không cần deploy, không cần đội phát hành bản
  mới hay chạy migration.
- CH-3: Ngày đông khách của một cửa hàng không làm chậm các cửa hàng khác:
  đọc sản phẩm và đặt đơn ở các cửa hàng còn lại vẫn trả lời như ngày thường.
- CH-4: Mỗi cửa hàng có cấu hình riêng (tên, thương hiệu trên app, email gửi
  khách), đổi được mà không cần deploy.

### Yếu tố định hình: một cửa hàng và 1.000 cửa hàng

| Yếu tố | Một cửa hàng (stage-3) | 1.000 cửa hàng (giả định) |
|---|---|---|
| Cô lập giữa cửa hàng | Không cần: chỉ có một | Bắt buộc (CH-1) |
| Mở cửa hàng mới | Không xảy ra | Vài cửa hàng mỗi tuần, không deploy (CH-2) |
| Cấu hình | Ghi trong code và cấu hình chung | Theo từng cửa hàng (CH-4) |
| Cửa hàng đông nhất | Là toàn bộ tải | Vài cửa hàng lớn giữ phần lớn số đơn; một cửa hàng có thể chiếm 10% tổng số đơn trong ngày khuyến mãi của nó (CH-3) |
| Đơn mỗi cửa hàng mỗi ngày | Như hôm nay | Trung bình 50, cửa hàng lớn nhất tới 5.000 |
| Người làm hệ thống | Một đội: product owner, scrum master, bốn lập trình viên, một tester | Ba tới bốn đội |
| Hoàn tiền, email, quy tắc đơn | Như `refund-requirements.md` và code hiện có | Không đổi trong mỗi cửa hàng |

Tổng số đơn và số lần đọc sản phẩm tăng theo số cửa hàng, nhưng ước lượng tải
và dung lượng là một việc riêng, không làm trong tài liệu này.

### Không đổi

Trong mỗi cửa hàng, hoàn tiền vẫn theo YC-1 tới YC-10 của
`refund-requirements.md`, email đơn hàng vẫn gửi như hôm nay, quy tắc trạng
thái của đơn giữ nguyên. Những phần đã xây cho các việc đó giữ được hình dạng
của chúng; thứ thay đổi là mỗi dòng dữ liệu phải biết nó thuộc cửa hàng nào.

### Ngoài phạm vi

- Một khách mua ở nhiều cửa hàng bằng một tài khoản.
- Bảng giá, gói dịch vụ và thanh toán của cửa hàng cho Đơn Hàng.
- Báo cáo gộp nhiều cửa hàng.

### Câu hỏi mở

| Câu hỏi | Ai trả lời | Hạn |
|---|---|---|
| Có hợp đồng nào đòi một bản hệ thống riêng cho một cửa hàng không? | Product owner, cùng bộ phận kinh doanh | Trước khi chọn kiến trúc |
| Cửa hàng có cần khôi phục dữ liệu riêng của mình về một thời điểm không? | Product owner | Trước khi chọn cách lưu dữ liệu |
| Cửa hàng được cam kết mức sẵn sàng nào trong hợp đồng? | Product owner, cùng bộ phận pháp chế | Trước khi ký cửa hàng đầu tiên |

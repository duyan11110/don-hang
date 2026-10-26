# 0018. DonHang.App gọi thẳng DonHang.Api, chưa thêm BFF

Trạng thái: Đã chấp nhận
Ngày: đề xuất đầu Sprint 21, quyết định cuối tuần đầu Sprint 21
Người quyết định: trưởng nhóm
Hạn góp ý: hết thứ Sáu tuần đầu Sprint 21

### Bối cảnh

DonHang.App gọi `DonHang.Api` qua Caddy (`localhost:8080/api/v1`), và trên
cluster qua Gateway. Ở stage-4 có một loại client (app của khách) và một đội.
Mỗi màn hình hiển thị dữ liệu của Đơn Hàng lấy nó bằng một request tới API:
danh sách sản phẩm, một sản phẩm, một đơn; đặt đơn là một request. App không
gọi Payments: hoàn tiền do API nhận rồi chuyển cho Payments. Các lời gọi nằm
trong `lib/features/catalog/catalog_api.dart` và
`lib/features/ordering/orders_api.dart`.

Câu hỏi đặt ra khi chuẩn bị cho nhiều cửa hàng: có nên đặt một backend for
frontend (BFF), một service phía server làm riêng cho app, giữa app và các
service không.

### Các phương án

- Giữ nguyên: app gọi thẳng API. Không thêm gì để chạy; câu trả lời của API
  đã đúng hình dạng màn hình cần.
- Một BFF cho DonHang.App: một service gọi API (và Payments khi cần), ghép và
  cắt câu trả lời theo từng màn hình. Có ích khi các client cần dữ liệu khác
  nhau hoặc một màn hình cần ghép nhiều service; hôm nay không có trường hợp
  nào như vậy, nên nó chỉ thêm một service phải deploy, giám sát, và thêm một
  chặng mạng cho mỗi request.
- Một API cho phép client tự chọn field cần lấy: một cổng truy vấn chung cho
  mọi client. Giải quyết việc lấy thừa hay thiếu dữ liệu, nhưng app chưa gặp
  việc đó, và đội phải học, bảo vệ và giới hạn tải cho một kiểu API mới.

### Quyết định

Chọn giữ nguyên: DonHang.App tiếp tục gọi thẳng DonHang.Api. Một loại client,
một đội, câu trả lời đã vừa với màn hình: chưa có vấn đề nào mà BFF giải
quyết, còn chi phí của nó thì có ngay. Caddyfile và Gateway không đổi.

### Hệ quả

- Không thêm service. Kiểm quyền vẫn ở API: ai được đọc một đơn do
  `DonHang.Api` quyết định, như đã làm sau API gateway.
- Hình dạng câu trả lời mà app dựa vào được giữ bằng hợp đồng
  `contracts/app/`: app kiểm nó đọc được các mẫu
  (`DonHang.App/test/api_contract_test.dart`), API kiểm nó vẫn trả đủ các field
  đó (`DonHang.Tests/Integration/AppContractTests.cs`).
- Nếu sau này có BFF, nó chỉ phục vụ client của nó: không giữ quy tắc nghiệp
  vụ, và không thay việc kiểm quyền của các service phía sau.

Đội xem lại quyết định khi:

- Có loại client thứ hai (ví dụ app cho nhân viên cửa hàng) mà câu trả lời của
  API không hợp, và sửa API cho client đó sẽ làm khó client kia.
- Một màn hình phải ghép dữ liệu từ API và Payments.

### Ý kiến đã nhận

Có ý kiến đề nghị dựng BFF ngay để sau này đỡ phải chèn vào. Không: chèn một
BFF vào sau không đổi API phía sau, chỉ đổi địa chỉ app gọi; làm sớm thì trả
chi phí vận hành từ hôm nay cho một nhu cầu chưa có.

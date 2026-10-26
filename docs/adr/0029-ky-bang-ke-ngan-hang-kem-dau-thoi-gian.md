# 0029. Ký bảng kê cho ngân hàng kèm dấu thời gian và trạng thái thu hồi

Trạng thái: Đã chấp nhận
Ngày: đề xuất giữa Sprint 25, quyết định cuối Sprint 25
Người quyết định: trưởng nhóm, cùng product owner
Hạn góp ý: hết thứ Sáu tuần thứ hai Sprint 25

Chưa xây ở stage-4: không có code ký bảng kê; `InvoiceSigning.cs` và
`InvoiceCertificates.cs` trong `samples/` không đổi. Thiết kế và buổi review ở
`docs/design/bank-signing-design-review.md`.

### Bối cảnh

`docs/team/bank-signing-requirements.md`: ngân hàng tự kiểm bảng kê chỉ bằng
public key và chứng chỉ, trong 10 năm (giả định), sau khi chứng chỉ hết hạn, và
phân biệt bảng kê ký trước, sau khi chứng chỉ bị thu hồi. Khóa nằm trong dịch
vụ HSM của nhà cung cấp (ADR 0015, 0023). Nhiều nhất vài trăm bảng kê mỗi tháng,
được chờ ký vài giờ (giả định).

### Các phương án

- Ký bằng giờ của server và một root riêng của Đơn Hàng, như
  `InvoiceCertificates.cs` trong lab: ngân hàng không tin root đó, và ai giữ
  khóa lộ cũng đặt được giờ server về trước lúc thu hồi.
- Ký trong HSM của nhà cung cấp bằng một khóa riêng cho ngân hàng, chứng chỉ
  do CA ngân hàng chỉ định cấp, kèm dấu thời gian của một timestamp authority và
  trạng thái thu hồi lấy lúc ký.
- Như trên nhưng trong HSM riêng của Đơn Hàng: bị loại theo lý do của ADR 0023
  (thiết bị ở hai nơi, người vận hành chúng).
- Dùng chung khóa ký hóa đơn: một lần thu hồi chạm hóa đơn của mọi cửa hàng
  khác.

### Quyết định

Chọn phương án thứ hai.

- Payments ký mỗi bảng kê trong dịch vụ HSM của nhà cung cấp (ADR 0023), bằng
  một khóa chỉ dùng cho bảng kê của ngân hàng này. Khóa tạo trong HSM; chứng chỉ
  cho khóa đó do CA ngân hàng chỉ định cấp (giả định).
- Payments xin dấu thời gian từ một timestamp authority cho chữ ký: chỉ gửi
  hash, không gửi bảng kê.
- Payments lấy trạng thái thu hồi của chứng chỉ lúc ký: hỏi responder OCSP của
  CA; responder không có thì dùng CRL của CA.
- Lưu một gói: đúng các byte của bảng kê, chữ ký, chuỗi chứng chỉ, dấu thời
  gian, trạng thái thu hồi.
- Mỗi lần xin ký, xin dấu thời gian, lấy trạng thái ghi một entry vào nhật ký
  kiểm toán (`docs/design/audit-log.md`).
- HSM, timestamp authority hay CA lỗi: bảng kê chờ, thử lại trong vài giờ (giả
  định); nhận đơn và hoàn tiền không bị ảnh hưởng.
- Gói được đóng dấu thời gian lại trước khi chứng chỉ của timestamp authority
  hết hạn.

### Hệ quả

- Thêm một khóa và một chứng chỉ phải gia hạn; thu hồi nó không chạm hóa đơn.
- Ký phụ thuộc ba dịch vụ bên ngoài: HSM, timestamp authority, CA.
- Gói lớn hơn chữ ký đơn thuần, nhưng ngân hàng kiểm sau 10 năm không cần dịch
  vụ của CA còn chạy.
- Một job định kỳ đóng dấu thời gian lại: chi phí lặp lại.

Đội xem lại quyết định khi: hợp đồng đòi khóa trên máy riêng (điều kiện mở lại
của ADR 0022 và ADR 0023; một ADR mới thay ADR 0023 cho đúng khóa này); ngân
hàng đòi một định dạng chữ ký riêng; một ngân hàng thứ hai cần bảng kê.

### Ý kiến đã nhận

Kế toán hỏi có cần ký lại toàn bộ bảng kê cũ khi chứng chỉ hết hạn không.
Không: dấu thời gian và trạng thái đã lưu cho thấy chứng chỉ còn hiệu lực lúc
ký; chỉ dấu thời gian phải được đóng lại. Quyết định không đổi.

# 0015. Khóa ký hóa đơn nằm trong HSM, chỉ Payments được gọi

Trạng thái: Đã chấp nhận
Ngày: đề xuất đầu Sprint 20, quyết định cuối tuần đầu Sprint 20
Người quyết định: trưởng nhóm
Hạn góp ý: hết thứ Sáu tuần đầu Sprint 20

### Bối cảnh

Mỗi đơn đã thanh toán sẽ có một hóa đơn ký số. Khách hoặc kiểm toán phải kiểm
được hóa đơn mà không cần hỏi Đơn Hàng: họ chỉ cần chứng chỉ của Đơn Hàng và
khóa công khai trong đó. Hóa đơn được giữ nhiều năm, 10 năm (giả định, chờ bộ
phận kế toán xác nhận), và chữ ký phải còn kiểm được suốt thời gian đó.

Ai giữ khóa riêng thì ký được hóa đơn nhân danh Đơn Hàng. Một bản sao của
khóa ký giống hệt bản gốc và không để lại dấu vết ai đã dùng nó. Sample
`samples/DonHang.Samples/Samples/Security/InvoiceSigning.cs` tạo khóa trong bộ
nhớ; đó chỉ là cách làm của lab.

Payments là service duy nhất biết đơn nào đã thanh toán (phát hiện P6 của
`docs/design/threat-model.md`).

### Các phương án

- Khóa trong một SealedSecret mà Payments đọc lúc khởi động: không thêm thành
  phần nào, cùng cách giữ khóa API của cổng (ADR 0006). Nhưng khóa nằm trong
  bộ nhớ của Payments; ai chiếm được Payments, hay đọc được Secret trong
  cluster, chép được khóa và ký tiếp sau khi lỗ hổng đã được vá.
- Khóa trong một HSM chỉ Payments được gọi: HSM tạo khóa bên trong nó, ký khi
  được yêu cầu, và không cho khóa ra ngoài. Payments nhận chữ ký, không bao giờ
  nhận khóa. Thêm một thành phần phải vận hành hoặc thuê.

### Quyết định

Chọn HSM. Kẻ chiếm được Payments chỉ xin được chữ ký trong lúc còn chiếm,
không mang khóa đi được; sau khi vá, không chữ ký mới nào được tạo bằng khóa
đó.

HSM ký mọi thứ một bên được phép gửi tới, nên Payments tự giới hạn những gì
nó xin ký: chỉ hóa đơn của đơn mà Payments ghi là đã thanh toán, và mỗi lần
xin ký được ghi vào nhật ký kiểm toán (`docs/design/audit-log.md`).

### Hệ quả

- Không khóa ký hóa đơn nào nằm trong repo, trong Secret hay trong bộ nhớ của
  service.
- Khóa không xuất ra được: mất HSM là mất khóa. Khi đó Đơn Hàng tạo khóa mới,
  xin chứng chỉ mới cho khóa đó, và các hóa đơn đã ký vẫn kiểm được bằng
  chứng chỉ cũ.
- HSM chạy ở đâu (phần cứng của Đơn Hàng hay dịch vụ của nhà cung cấp hạ
  tầng) để quyết định về nơi chạy hệ thống quyết, đã quyết ở ADR 0023 (dịch
  vụ HSM của nhà cung cấp).
- Khóa phần mềm trong sample chỉ dùng cho lab.
- Ở stage-4 chưa có hóa đơn, chưa có HSM: chỉ có sample và ADR này.

Đội xem lại khi một bên ngoài (cơ quan nhà nước, ngân hàng) đòi ký bằng
chứng chỉ do họ cấp theo cách riêng, hoặc khi một service khác ngoài Payments
cần ký.

### Ý kiến đã nhận

Lập trình viên phụ trách nền tảng hỏi SealedSecret có đủ không, vì nó đã bảo
vệ khóa API của cổng. Không: khóa API lộ thì đổi được ở cổng và các lần gọi
cũ không còn giá trị; khóa ký lộ thì chữ ký làm bằng bản sao không phân biệt
được với chữ ký thật của Đơn Hàng.

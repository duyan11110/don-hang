# Lịch phát hành cho cửa hàng

Trạng thái: quy ước từ stage-4. API Đơn Hàng chưa có feature flag nào
(`docs/design/feature-flags.md`), nên lịch này là quy ước cho tính năng đầu
tiên cửa hàng thấy được và các tính năng sau, chưa phải điều đang chạy.

Lịch này chạy theo kiểu release train: phát hành vào những ngày cố định, công
bố trước. Thay đổi nào sẵn sàng khi chuyến khởi hành thì đi; thay đổi chưa sẵn
sàng chờ chuyến sau, chuyến không chờ nó.

### Chuyến phát hành

- Một chuyến vào cuối mỗi sprint hai tuần.
- Chuyến chỉ dành cho thay đổi cửa hàng thấy được. Phát hành ở đây nghĩa là
  bật feature flag của thay đổi đó theo `feature-flags.md`, không phải deploy.
- Code vẫn lên production bất kỳ ngày nào, qua canary của ADR 0019, với flag
  đang tắt. Deploy và phát hành tách nhau: deploy là việc của đội, phát hành là
  việc cửa hàng được báo trước.
- Thay đổi cửa hàng không thấy (sửa bên trong, nâng thư viện, thay đổi nền
  tảng) không đi theo chuyến; chúng lên production khi xong.

### Trước mỗi chuyến

- Ghi chú phát hành của chuyến tới cửa hàng trước ngày chuyến 5 ngày làm việc,
  để cửa hàng chuẩn bị nhân viên và khách của mình.
- Thay đổi chưa sẵn sàng vào lúc đó (code chưa lên production, chưa qua đủ
  bước canary, chưa có trong ghi chú) đi chuyến sau. Chuyến không lùi ngày để
  chờ nó, vì cửa hàng đã được báo ngày đó.
- Product owner chốt danh sách thay đổi của chuyến.

### Ngoài lịch

Sửa một sự cố hoặc một lỗ hổng bảo mật không chờ chuyến:

- Ai được phát hành ngoài lịch: người chỉ huy sự cố trong lúc có sự cố, theo
  `incident-response.md`; trưởng nhóm với bản vá lỗ hổng không gắn với sự cố
  nào.
- Bản sửa vẫn đi qua canary của ADR 0019, kể cả khi error budget đã hết theo
  `slo.md`.
- Cách báo cửa hàng: thông báo trong ngày cho các cửa hàng bị ảnh hưởng, nói
  điều đã sửa và cửa hàng có phải làm gì không; thay đổi đó được ghi lại trong
  ghi chú của chuyến kế tiếp.

### Đổi phá vỡ

Thay đổi buộc cửa hàng phải làm khác đi (bỏ một tính năng, đổi cách dùng một
màn hình hay một API cửa hàng gọi) được báo trước ít nhất hai chuyến, trong
ghi chú phát hành của cả hai chuyến đó.

### Cái giá

Chuyến đổi tốc độ lấy sự dễ đoán: một thay đổi đã xong có thể chờ tới hai tuần
mới được bật. Cái giá đó hợp với thay đổi mà 1.000 cửa hàng (giả định) phải biết trước,
không hợp với thay đổi bên trong, nên thay đổi bên trong không đi theo chuyến.

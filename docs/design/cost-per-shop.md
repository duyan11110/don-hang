# Thiết kế: chi phí mỗi cửa hàng

Trạng thái: mô hình từ stage-4, không đổi code hay cấu hình. Đi cùng ADR 0033
(gói là dữ liệu): giá mỗi gói phải trả được phần chi phí của các cửa hàng trong
gói. Mọi con số ghi "giả định" là để so các lựa chọn, không phải giá của nhà
cung cấp nào. Chi phí cluster tính ở `cluster-cost.md`; file này không sửa nó.

### Chi phí chung chia theo mức dùng

Phần lớn chi phí của một cửa hàng là chi phí chung: node (số node theo tổng
request, `cluster-cost.md`), server database, platform cố định mỗi cluster. Các
thứ đó phục vụ mọi cửa hàng cùng lúc. Vì vậy chi phí mỗi cửa hàng không phải
hóa đơn riêng của cửa hàng đó, mà là chi phí chung chia theo mức dùng đo được.

- Chi phí cửa hàng = chi phí chung của tháng × phần dùng của cửa hàng.
- Phần dùng đo bằng các số đếm ở mục dưới; mỗi cách chia là một ước lượng.
- Chi phí cố định mỗi cluster chia đều cho mọi cửa hàng (ước lượng): nó không
  tăng theo mức dùng.

### Đếm gì

Đếm mức dùng của từng cửa hàng (usage metering) bằng vài số:

| Số đếm | Nguồn | Chia phần nào của chi phí (ước lượng) |
|---|---|---|
| Request được phục vụ, bị từ chối, theo cửa hàng | Counter có nhãn cửa hàng của ADR 0016 | Node của api |
| Số đơn và số dòng lưu mỗi cửa hàng | Đếm theo `shop_id` trong database, mỗi ngày một lần | Server database, sao lưu |
| Kết nối chat mở mỗi cửa hàng | Support (ADR 0032), khi có | Node của Support |

Cửa hàng có database riêng (ADR 0026) mang trọn chi phí database đó, cộng phần
chia của phần còn lại.

### Nhãn cửa hàng chỉ trên counter

Mỗi giá trị của một nhãn thêm time series. Nhãn cửa hàng trên một counter thêm
một series cho mỗi cửa hàng: 1.000 cửa hàng là khoảng 1.000 series cho mỗi tổ
hợp nhãn khác. Trên một histogram, nó thêm một series cho mỗi cửa hàng nhân với
mỗi bucket. Vì vậy chi tiết theo cửa hàng chỉ nằm trên counter, như ADR 0016 đã
quyết; histogram thời gian trả lời giữ không có nhãn cửa hàng.

### Trace: đang có gì

- `DonHang.Api/Program.cs`: trace bắt đầu ở api được giữ với xác suất
  `Telemetry:SampleRatio`, mặc định 0,1; span có cha theo quyết định của cha,
  nên một trace được giữ hay bỏ trọn vẹn.
- Compose đặt `Telemetry__SampleRatio` là `1.0`: lab giữ mọi trace.
- ConfigMap của api ở staging và production đặt `OTEL_SDK_DISABLED: "true"`:
  chưa có trace nào ở đó.
- Tempo của lab giữ trace 24 giờ (`block_retention: 24h` trong
  `deploy/monitoring/tempo.yml`).
- SLI không phụ thuộc tỉ lệ sampling: S1–S4 của `slo.md` đến từ metric, đếm mọi
  request.

### Chọn tỉ lệ sampling theo SLO

Câu hỏi: tỉ lệ nào để lại đủ trace lỗi để giải thích một lần đốt error budget.

- S1: khoảng 1,4 triệu request đặt đơn trong 28 ngày (50.000 mỗi ngày, giả
  định). SLO 99,5% cho phép khoảng 7.000 request xấu. Một sự cố tiêu một phần
  tư budget (ngưỡng viết postmortem của `slo.md`) là khoảng 1.750 request xấu;
  với tỉ lệ 0,1, khoảng 175 trace lỗi được giữ. Đủ.
- S4: khoảng 14.000 yêu cầu hoàn tiền trong 28 ngày (giả định), SLO 99% cho
  phép khoảng 140 request xấu; một phần tư là khoảng 35, với 0,1 còn khoảng 3
  trace. Ít, nhưng log của request vẫn có đủ.

Quyết định cho production (giả định): giữ 0,1, mặc định của code, không đổi
code. Giữ trace theo kết quả (chờ cả trace rồi giữ mọi trace lỗi) giải quyết
trường hợp S4, nhưng chỉ là phương án nói bằng lời, chưa làm.

### Thời gian giữ

- Trace: giữ lâu hơn thời gian điều tra một sự cố và viết postmortem, vài ngày;
  production giữ 7 ngày (giả định). 24 giờ của lab không đủ: sự cố tối thứ Sáu
  được điều tra sáng thứ Hai.
- Log: cùng lý do, 7 ngày (giả định).
- Metric: theo cửa sổ 28 ngày của SLO, tối thiểu 28 ngày.

### Điểm đánh đổi: chi tiết so với chi phí

Đo chi tiết hơn (thêm số đếm, thêm trace, giữ lâu hơn) cho giá gói công bằng
hơn và tìm lỗi nhanh hơn, nhưng mỗi series và mỗi span đều tốn chỗ lưu. Thuộc
tính được lợi: khả năng chẩn đoán, sự công bằng của giá gói. Thuộc tính bị
thiệt: chi phí telemetry, chính nó cũng là chi phí chung phải chia cho các cửa
hàng. Driver quyết định: biết chi phí mỗi cửa hàng của từng gói, ở mức đủ để
đặt giá, không hơn.

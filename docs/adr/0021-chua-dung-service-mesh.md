# 0021. Chưa dùng service mesh

Trạng thái: Đã chấp nhận
Ngày: đề xuất giữa Sprint 21, quyết định cuối Sprint 21
Người quyết định: trưởng nhóm
Hạn góp ý: hết thứ Năm tuần thứ hai Sprint 21

### Bối cảnh

Phát hiện P5 của `threat-model.md` chấp nhận rằng Gateway gọi các Pod api
bằng HTTP thường: NetworkPolicy quyết định ai được kết nối, nhưng dữ liệu đi
qua mạng giữa các node không mã hóa, và api chỉ biết bên gọi qua địa chỉ của
nó. Một service mesh đặt một proxy cạnh mỗi Pod; các proxy đó mã hóa mọi lời
gọi bằng mutual TLS và còn làm nhiều việc khác. Câu hỏi là Đơn Hàng có cần
mesh không.

Đơn Hàng có ba service .NET (api, Notifications, Payments) và một nhóm. Những
gì mesh làm được, so với những gì đã có:

| Mesh làm được | Đơn Hàng đã có |
|---|---|
| Quyết định ai được gọi ai | NetworkPolicy cho ingress và egress của từng service |
| Kiểm bên gọi ở mức request | Token của Keycloak, kiểm bằng `AddJwtBearer` trong api và Payments |
| Retry, timeout, circuit breaker | Resilience pipeline của Payments khi gọi cổng thanh toán |
| Trace qua các service | OpenTelemetry trong cả ba service |
| Chia traffic cho canary | Trọng số của HTTPRoute (ADR 0019) |
| Mã hóa lời gọi trong cluster | Chưa có |
| Danh tính của bên gọi không dựa vào địa chỉ | Chưa có |

Hai dòng cuối là hai khoảng trống thật.

### Các phương án

- A. Chưa dùng mesh; giữ P5 ở trạng thái chấp nhận.
- B. Cài một mesh chỉ để có mutual TLS giữa mọi service.
- C. Chỉ mã hóa chặng Gateway tới api: api phục vụ HTTPS bằng chứng chỉ do
  cert-manager cấp, Gateway gọi api qua HTTPS. Không thêm thành phần mới chạy
  cạnh Pod.

Cái giá của B:

- Một proxy trong mỗi Pod, tốn bộ nhớ và CPU ở từng Pod, và thêm một chặng
  trên mọi lời gọi.
- Controller của mesh là thêm một thành phần platform phải nâng cấp, theo dõi
  và hiểu khi nó hỏng.
- Proxy nằm trên đường đi của mọi lời gọi, nên một cấu hình mesh sai hoặc một
  lần nâng cấp mesh hỏng có thể làm hỏng lời gọi giữa mọi service cùng lúc.

### Quyết định

Chọn A. Với ba service .NET và một nhóm, mesh chỉ lấp hai khoảng trống mà
chưa yêu cầu nào đòi lấp, và cái giá của nó trả cho mọi Pod, mọi lời gọi. P5
vẫn ở trạng thái chấp nhận.

Nếu chỉ cần mã hóa, C là bước đầu: nó lấp khoảng trống ở chặng lộ ra nhiều
nhất (từ Gateway vào) với chi phí nhỏ nhất.

### Hệ quả

- Lời gọi trong cluster vẫn không mã hóa; NetworkPolicy vẫn là lớp quyết định
  ai được kết nối.
- Không có thêm thành phần nào để nâng cấp hay diễn tập.

Ba điều kiện mở lại:

- Một hợp đồng đòi mã hóa lời gọi bên trong cluster. Nếu chỉ đòi mã hóa, làm
  C trước khi tính tới mesh.
- Service đến từ nhiều nhóm hoặc nhiều ngôn ngữ, nên mỗi codebase tự làm
  mutual TLS, retry và số đo theo lời gọi trở nên đắt hơn một mesh.
- Service bắt đầu gọi nhau giữa các cluster.

### Ý kiến đã nhận

Lập trình viên backend đề nghị làm C ngay vì chi phí nhỏ. Đội không làm:
chứng chỉ của api thêm một việc gia hạn và một chỗ có thể hỏng ở đường vào
chính, cho một khoảng trống chưa ai yêu cầu lấp. C được ghi vào mục Quyết
định như bước đầu khi điều kiện thứ nhất xảy ra.

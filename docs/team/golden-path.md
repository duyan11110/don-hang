# Golden path cho một service .NET mới

Golden path là con đường được hỗ trợ và có tài liệu để thêm một service vào
Đơn Hàng. Đi theo nó, service mới đã đáp ứng các luật của platform ngay từ
đầu, không phải chép manifest từ một service khác rồi sửa. Đây là đường mặc
định, không phải luật: nhóm được rời nó, và khi đó tự lo phần nó cho sẵn.

### Các bước

1. Viết code service trong thư mục riêng, có Dockerfile với hai target như
   `DonHang.Payments/Dockerfile`: image của service và image migration.
2. Chạy `scripts/devops/new-service.sh <tên>`. Script sinh từ
   `templates/dotnet-service/` các file Kustomize service cần, chạy
   `kubectl kustomize` và kubeconform trên chúng, rồi in danh sách file và kết
   quả kiểm.
3. Chép các file đã sinh vào repo cấu hình, ghi digest của image, mở pull
   request.
4. Làm các bước ở mục "Chưa tự phục vụ" của `platform-capabilities.md`, mỗi
   bước một pull request tới người giữ phần đó.
5. Viết SLO của service vào `docs/design/slo.md` trước khi service nhận traffic
   thật.

### Phần path cho sẵn

- Deployment có probe `/health/live` và `/health/ready`, security context như
  của `api` (không chạy bằng root, không leo quyền, bỏ mọi Linux capability,
  seccomp profile mặc định của runtime), và
  `automountServiceAccountToken: false`.
- Service, và migration chạy như hook của Argo CD trước Deployment.
- NetworkPolicy cho cả ingress lẫn egress: mặc định không ai gọi được service
  và service không gọi ra được đâu, trừ DNS và những gì được thêm.
- Image ghi bằng digest, nên admission policy `require-image-digest` nhận Pod.
- Các file qua được cùng phép kiểm repo cấu hình đang có: `kubectl kustomize`
  và kubeconform với image đã ghim như job `manifests` của CI.
- Image được ký và quét lỗ hổng khi đi qua các job CI `image` và `publish`
  (thêm service vào đó là một bước "chưa tự phục vụ").

### Phần nhóm tự lo

- Code của service và test của nó.
- Migration database và việc giữ schema chạy được với bản trước (ADR 0019).
- SLO, và việc trả lời khi service tiêu hết error budget.
- Request CPU và bộ nhớ: template đặt giá trị nhỏ để khởi đầu, nhóm đo rồi
  chỉnh.

### Rời path thì sao

Một nhóm có lý do để làm khác (một runtime khác, một cách deploy khác) được
làm khác. Khi đó nhóm tự giữ những gì path đã cho: viết và kiểm manifest, theo
kịp khi template đổi, và trả lời câu hỏi review về các luật mà template vốn đã
đáp ứng. Rời path được ghi trong pull request, kèm lý do.

### Vì sao luật bắt buộc nằm ở phép kiểm

File sinh từ template một lần thì không theo template về sau: sửa template
không sửa các service đã sinh trước đó, và nhóm rời path không dùng template.
Vì vậy luật phải đúng với mọi service được giữ bằng một phép kiểm chạy trên mọi
manifest, như admission policy `require-image-digest` trong cluster hay
kubeconform trong CI, chứ không chỉ bằng template. Template giúp làm đúng từ
đầu; phép kiểm chặn khi làm sai, dù file từ đâu ra.

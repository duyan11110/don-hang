# Checklist review cluster

Trạng thái: dùng từ stage-4. Checklist cho những thay đổi chạm tới cluster,
không chỉ tới một service. Mỗi câu hỏi trỏ tới phép kiểm hoặc quyết định trả
lời nó, để người review không phải nhớ hay tranh luận lại. Câu hỏi chưa có phép
kiểm thì người review tự kiểm. Thay đổi trong code của một service dùng
`backend-review-checklist.md`; các phép kiểm tự động của toàn hệ thống được
liệt kê trong `fitness-functions.md`.

### Khi nào cần review

Khi thay đổi vượt quá một service:

- thêm một CRD hay một operator;
- thêm namespace cho một nhóm mới;
- thêm một cluster hay một môi trường;
- nâng phiên bản Kubernetes hay một add-on của cluster;
- đổi cách thay đổi tới cluster (Argo CD, repo cấu hình, CI).

Sửa manifest của một service trong overlay của nó không cần review này: các
phép kiểm bên dưới đã chạy trên mọi manifest.

### Workload và tài nguyên

- Mỗi container đã đặt request CPU và bộ nhớ chưa? Pod không request làm
  scheduler tính sai chỗ trống (`cluster-cost.md`). Người review tự kiểm.
- Deployment mới có probe `/health/live`, `/health/ready` và security context
  như `api` chưa? Template của golden path (`golden-path.md`) cho sẵn.
- Image có ghi bằng digest không? Admission policy `require-image-digest` từ
  chối Pod không có digest.
- Manifest có hợp lệ với schema của Kubernetes không? Kubeconform trong job
  `manifests` của CI.

### Cô lập và quyền

- Namespace có nhãn Pod Security không? Lớp platform của OpenTofu đặt
  `enforce` theo môi trường, `warn` và `audit` ở `restricted`.
- Service mới có NetworkPolicy cho cả ingress và egress chưa, hay chỉ dựa vào
  mặc định chặn hết? Người review tự kiểm; template cho sẵn.
- Pod có cần token của ServiceAccount không, hay để
  `automountServiceAccountToken: false` như các service hiện có?
- Lời gọi trong cluster có cần mã hóa không? ADR 0021 trả lời: chưa, và nêu
  khi nào mở lại.

### Dữ liệu và sao lưu

- Workload mới có giữ dữ liệu không? Nếu có, nó đã nằm trong job sao lưu hằng
  đêm và đã được thử khôi phục chưa? Sao lưu chưa từng khôi phục thì chưa phải
  sao lưu.
- Volume có ghi `storageClassName` khi môi trường cần một StorageClass xác
  định không (`cluster-migration-plan.md`)?
- Thay đổi có ảnh hưởng RTO và RPO của ADR 0020 không?

### Nâng cấp và add-on

- Operator hay add-on mới có người chịu trách nhiệm nâng cấp chưa, ghi trong
  `self-run-components.md`? Một operator không ai nâng cấp sẽ chặn lần nâng
  Kubernetes sau.
- Phiên bản của add-on có chạy được với phiên bản Kubernetes của cluster, và
  với phiên bản kế tiếp không?
- Workload chạy nhiều replica có PodDisruptionBudget để lần nâng cấp node không
  rút hết Pod cùng lúc không?

### Chi phí

- Thay đổi thêm bao nhiêu request, và còn vừa số node hiện có không
  (`cluster-cost.md`)?
- Thêm cluster hay môi trường thì phần nền cố định được trả thêm một lần: đã
  tính chưa?
- Thay đổi có gắn thêm vào nhà cung cấp ở chỗ ADR 0022 chưa liệt kê không?

### Cách thay đổi tới cluster

- Thay đổi đi qua repo cấu hình và Argo CD, hay có bước nào làm bằng
  `kubectl` ngoài Git? Thay đổi bằng tay bị self-heal của Argo CD trả lại,
  hoặc tệ hơn là ở lại mà không ai biết.
- Secret mới có ở dạng SealedSecret không (ADR 0006)?
- Thành phần mới phát hành theo cách nào trong ADR 0019?
- Khóa hay secret quan trọng có nằm ngoài dịch vụ quản lý khóa không (ADR
  0023)?

### Ví dụ: cho HPA scale `api` ở production

Đề xuất đã qua review, chưa đổi manifest:

- `replicas` được bỏ khỏi Deployment `api` trong Git; nếu không, Argo CD trả
  số replica về giá trị trong Git mỗi lần đồng bộ, đè lên số HPA đặt.
- `maxReplicas` được giới hạn sao cho số Pod api nhân số kết nối mỗi Pod vẫn
  dưới `max_connections` của PostgreSQL, như `capacity-plan.md` tính. Thêm
  node không nâng giới hạn này.
- `minReplicas` không dưới 2, để một Pod hỏng không làm api ngừng phục vụ.
- Một PodDisruptionBudget cho `api` giữ ít nhất một Pod khi node được nâng
  cấp hay rút khỏi cluster.
- Request CPU của `api` giữ như hiện tại: HPA tính mức dùng theo phần trăm của
  request, nên đổi request là đổi điểm scale.
- Cluster production cần nguồn số đo CPU cho HPA; lab không có, nên ví dụ này
  chỉ được kiểm trên cluster managed.

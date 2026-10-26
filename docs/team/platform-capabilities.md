# Năng lực platform của Đơn Hàng

Platform ở đây là các công cụ, giá trị mặc định và tài liệu dùng chung mà
mọi service chạy trên đó, không thuộc riêng service nào. Đơn Hàng chưa gọi nó
là platform và chưa có nhóm riêng giữ nó: các phần dưới đây được dựng dần qua
stage-2 và stage-3, mỗi phần cho một việc cụ thể. Tài liệu ghi những gì đang
có ở stage-4, mỗi phần dùng để làm gì, ai giữ, và một nhóm sản phẩm tự làm
được với nó hay phải nhờ người giữ.

### Năng lực đang có

| Năng lực | Dùng để làm gì | Ai giữ | Nhóm tự làm được? |
|---|---|---|---|
| Lớp cluster của OpenTofu (`deploy/tofu/envs/*/cluster`, module `kind-cluster`) | Tạo cluster của mỗi môi trường | Trưởng nhóm | Không: phải nhờ |
| Lớp platform của OpenTofu (module `donhang-platform`) | Namespace `donhang` với nhãn Pod Security, khóa niêm secret | Trưởng nhóm | Không: phải nhờ |
| Argo CD và repo cấu hình | Deploy bằng commit vào `envs/`; Argo CD đồng bộ và tự sửa khi cluster lệch Git | Trưởng nhóm | Có: commit overlay của service mình, qua pull request |
| Gateway và HTTPRoute (`platform/edge/`) | Đưa request từ ngoài vào service theo host và đường dẫn | Trưởng nhóm | Một phần: sửa `httproutes.yaml` qua pull request, người giữ review |
| Sealed Secrets (`scripts/devops/seal-secrets.sh`) | Giữ secret trong repo cấu hình ở dạng đã mã hóa (ADR 0006) | Trưởng nhóm | Một phần: niêm bằng chứng chỉ công khai thì ai cũng làm được, nhưng script liệt kê từng Secret nên thêm Secret mới phải sửa script |
| Admission policy `require-image-digest` (`platform/policies/`) | Từ chối Pod dùng image của Đơn Hàng mà không ghi digest | Trưởng nhóm | Có: không phải làm gì nếu manifest ghi digest |
| Các job CI `image` và `publish` | Build image, viết SBOM, quét lỗ hổng, đẩy lên registry, ký digest và ghi provenance | Lập trình viên backend | Không: service mới phải thêm vào các job này trong `ci.yml` |
| Job CI `manifests` | Kiểm mọi manifest và overlay bằng kubeconform | Lập trình viên backend | Có: file mới nằm trong thư mục đã kiểm thì được kiểm |
| Prometheus của staging (namespace `monitoring`) | Đếm request theo Deployment cho canary (`canary-checks.md`); đánh giá recording rule và alert burn rate (`alerts.md`) | Lập trình viên backend | Không: chỉ scrape các Pod api, service mới phải sửa cấu hình |
| Golden path (`templates/dotnet-service/`, `scripts/devops/new-service.sh`) | Sinh sẵn manifest cho một service .NET mới (`golden-path.md`) | Trưởng nhóm | Có |

Các thành phần tự chạy khác của cluster (Git server, Traefik, controller của
Sealed Secrets) và việc định kỳ của chúng ở `self-run-components.md`.

### Chưa tự phục vụ

Những bước một service mới vẫn phải nhờ người khác sửa file chung.
`scripts/devops/service-footprint.sh payments` liệt kê đủ các file như thế
cho Payments; các bước chính:

- Thêm image vào các job `image` và `publish` của CI.
- Thêm nhãn `app` của service vào các NetworkPolicy của thành phần dùng chung
  (database, RabbitMQ, Keycloak), vì mỗi policy liệt kê từng nhãn được vào.
- Thêm database của service vào job sao lưu hằng đêm (`db-backup.yaml` liệt
  kê từng database), và thêm Secret của service vào `seal-secrets.sh`.
- Thêm route nếu service nhận request từ ngoài, và thêm vào cấu hình scrape
  của Prometheus nếu cần số đo trên staging.

Mỗi bước nhỏ, nhưng làm bằng cách chép từ service khác thì chép luôn cả lỗi và
giá trị mặc định cũ của service đó.

### Có cần một nhóm platform riêng

Ý kiến của trưởng nhóm, có điều kiện: chưa cần. Đơn Hàng có một nhóm, ba
service .NET, và một service mới mỗi vài quý. Ghi các bước xuống (golden path,
bảng trên) và giữ chúng đúng là đủ.

Điều đó đổi khi có từ hai nhóm sản phẩm trở lên cùng lặp lại các bước ở mục
"Chưa tự phục vụ", hoặc khi yêu cầu nhờ người giữ platform bắt đầu phải xếp
hàng. Khi đó platform được chạy như một sản phẩm cho người dùng nội bộ: đo
bằng việc các nhóm có chọn dùng nó không và bằng bốn số đo trong
`delivery-metrics.md`, không bằng số công cụ nó có.

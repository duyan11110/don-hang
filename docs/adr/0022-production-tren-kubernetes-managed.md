# 0022. Production chạy trên Kubernetes managed

Trạng thái: Đã chấp nhận
Ngày: đề xuất đầu Sprint 22, quyết định cuối tuần đầu Sprint 22
Người quyết định: trưởng nhóm, cùng product owner
Hạn góp ý: hết thứ Sáu tuần đầu Sprint 22

### Bối cảnh

Production chưa chạy ở đâu: `deploy/tofu/envs/production/cluster/main.tf`
chỉ mô tả một cluster kind với một control plane và hai worker, và OpenTofu
chỉ plan nó. Trước khi có khách thật, đội phải chọn cluster production chạy
trên gì.

Hệ thống nhiều cửa hàng (ADR 0012) cần chạy liên tục cho mọi cửa hàng, chịu
được đỉnh tải theo mùa, và do một nhóm vận hành. Kubernetes managed là dịch vụ
trong đó nhà cung cấp chạy control plane (API server, etcd, nâng cấp của
chúng) và cho thêm node theo node pool; đội vẫn lo mọi thứ chạy trên node.

Mọi số trong bảng là giả định để so ba phương án, tính trong ba năm, không
phải giá của nhà cung cấp nào. Phí được quy ra ngày công để so cùng đơn vị.

| Mỗi tháng (giả định) | A. Máy riêng | B. Managed, một nhà cung cấp | C. Hai nhà cung cấp |
|---|---|---|---|
| Ngày công vận hành cluster | 6 | 2 | 5 |
| Phí và khấu hao, quy ra ngày công | 3 | 4 | 7 |
| Tổng | 9 | 6 | 12 |

### Các phương án

- A. Máy riêng: kubeadm dựng control plane ba node, MetalLB cấp địa chỉ cho
  Gateway, Longhorn sao chép volume giữa các node. Không phí dịch vụ, dữ liệu
  ở chỗ đội chọn. Đội tự lo control plane, etcd, lưu trữ sao chép, nâng cấp
  và trực cho tất cả. Máy phải mua trước cho đỉnh tải dự kiến.
- B. Kubernetes managed của một nhà cung cấp: control plane và nâng cấp của nó
  do nhà cung cấp lo; node pool thêm node khi có đỉnh tải. Trả phí, và gắn với
  nhà cung cấp ở vài chỗ (mục Hệ quả).
- C. Multi-cloud, chạy cùng lúc trên hai nhà cung cấp: không phụ thuộc một
  nhà cung cấp. Gấp đôi platform phải chạy, và hệ thống chỉ dùng được những gì
  cả hai đều có.

### Quyết định

Chọn B. Một nhóm không giữ được control plane và lưu trữ sao chép chạy suốt
ngày đêm như A đòi, và node pool lớn lên theo đỉnh tải còn máy riêng phải mua
trước. C bị từ chối: nó gấp đôi platform để tránh một rủi ro mà kế hoạch rời
đi bên dưới đã giữ được khả năng rời đi.

Database và các thành phần tự chạy khác giữ như `self-run-components.md`:
ADR này chỉ quyết chỗ chạy cluster.

### Hệ quả

Chỗ gắn với nhà cung cấp:

- Tên StorageClass trong các manifest có volume.
- Load balancer của nhà cung cấp đứng trước Gateway, thay cho NodePort của
  lab và MetalLB.
- Dịch vụ quản lý khóa (ADR 0023).
- Mã OpenTofu của lớp cluster.

Phần chuyển nguyên sang nhà cung cấp khác: manifest, overlay Kustomize, Argo
CD và repo cấu hình, admission policy. Secret niêm lại bằng khóa của cluster
mới.

Ở stage-4 Đơn Hàng chưa có mã cho cluster managed; cách chuyển sang ở
`docs/design/cluster-migration-plan.md`.

### Kế hoạch rời đi

Rời nhà cung cấp đi theo đúng cách chuyển sang: dựng cluster mới cạnh cluster
cũ từ repo cấu hình, sửa các chỗ gắn ở trên, chuyển dữ liệu bằng base backup
và WAL, rồi đổi traffic (`cluster-migration-plan.md`). Kế hoạch được diễn tập
trên staging, không chờ ngày phải rời đi.

Điều kiện mở lại:

- Hợp đồng của một khách đòi máy riêng hoặc dữ liệu ở một nơi xác định.
- Phí của nhà cung cấp vượt chi phí giả định của việc đội tự chạy cluster (cột
  A của bảng).

### Ý kiến đã nhận

Product owner hỏi có nên chạy hai nhà cung cấp để thương lượng giá tốt hơn
không. Không: kế hoạch rời đi đã cho đội vị thế đó mà không phải chạy hai
platform. Quyết định không đổi.

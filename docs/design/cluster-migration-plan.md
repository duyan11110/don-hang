# Kế hoạch chuyển Đơn Hàng sang cluster managed

Trạng thái: chỉ là kế hoạch, chưa chạy. Kế hoạch chuyển Đơn Hàng sang cluster
Kubernetes managed của ADR 0022. Mọi thời gian ghi "giả định" cho tới khi
diễn tập trên staging đo được số thật.

### Cách chuyển

Cluster mới được dựng cạnh cluster cũ, rồi traffic mới đổi sang. Cluster cũ
vẫn chạy và là đường quay lại cho tới khi việc chuyển được kiểm xong.

Object Kubernetes không được chép sang: Argo CD trên cluster mới dựng lại
chúng từ repo cấu hình, như `scripts/devops/dr-drill.sh` dựng lại staging.
Không mang etcd snapshot của cluster cũ sang, vì nó mang theo node, địa chỉ và
Secret của cluster cũ. Chỉ dữ liệu là phải chuyển.

### Thứ khác nhau theo cluster

Những thứ này được sửa trong repo cấu hình trước, mỗi thứ một pull request,
trước khi cluster mới đồng bộ:

| Thứ khác nhau | Ở cluster cũ | Ở cluster mới | File phải sửa |
|---|---|---|---|
| Khóa niêm secret | Cặp khóa trong `secrets/`, cài bởi lớp platform | Cặp khóa mới cho cluster mới | Các SealedSecret của overlay, niêm lại bằng `scripts/devops/seal-secrets.sh` với chứng chỉ mới |
| StorageClass | Mặc định của cluster (volume không ghi `storageClassName`) | StorageClass của nhà cung cấp | Overlay của môi trường: ghi rõ `storageClassName` cho `db`, `rabbitmq`, `db-backups` |
| Địa chỉ Gateway | NodePort 30080 và 30443 của Traefik | Load balancer của nhà cung cấp | `apps/traefik.yaml` (kiểu Service), bản ghi DNS của hai tên miền production (cho api và cho đăng nhập) |
| Mã cluster | Module `kind-cluster` | Module cluster managed | `deploy/tofu/envs/production/cluster/main.tf` |

### Chuyển dữ liệu

- PostgreSQL: khôi phục base backup mới nhất vào database ở cluster mới rồi
  cho nó đọc tiếp WAL từ bản lưu trữ, cùng cách `pitr.sh` khôi phục. Khi nó đã
  đuổi kịp, dừng ghi một lúc ngắn (15 phút, giả định): một commit đặt số
  replica của `api` ở cluster cũ về 0, nên không đơn và không message mới nào
  được tạo. Đổi bằng commit chứ không bằng `kubectl scale`, vì self-heal của
  Argo CD sẽ trả lại số replica trong Git.
- RabbitMQ: trong lúc dừng ghi, Notifications và Payments ở cluster cũ vẫn
  chạy cho tới khi các queue xả hết, rồi mới về 0 cũng bằng commit. Không
  message nào bị bỏ lại trong queue của cluster cũ; message còn trong
  dead-letter queue được xử lý xong trước bước này.
- Sau đó đợi đoạn WAL cuối được áp vào database mới, rồi mở nó cho ghi.
- Redis chỉ giữ cache, không chuyển; cache ở cluster mới đầy lại dần.

Nhờ vậy không đơn nào đã được xác nhận cho khách bị mất.

### Đổi traffic và đường quay lại

1. Cluster mới đồng bộ xong, database mới đã đuổi kịp, smoke test qua địa chỉ
   mới của Gateway.
2. Dừng ghi, xả queue, áp đoạn WAL cuối (mục trên).
3. Đổi DNS sang Gateway mới, mở ghi trên cluster mới.
4. Giữ cluster cũ chạy (không nhận traffic) 14 ngày (giả định).

Quay lại trước bước 3 chỉ cần không đổi DNS. Sau bước 3, đơn mới chỉ nằm ở
cluster mới: quay lại nghĩa là chuyển dữ liệu theo chiều ngược, nên mọi kiểm
tra phải xong trước khi mở ghi.

### Chỉ đổi cluster

Lần chuyển này chỉ đổi cluster. Thành phần tự chạy (PostgreSQL, RabbitMQ,
Keycloak, theo `docs/team/self-run-components.md`) chuyển nguyên như đang
chạy. Đổi chúng sang dịch vụ managed là việc sau, mỗi bản phát hành một thành
phần, để khi có lỗi thì biết ngay thay đổi nào gây ra.

### Diễn tập

Trước khi chuyển production, toàn bộ kế hoạch chạy trên staging: dựng một
cluster staging thứ hai, chuyển dữ liệu staging, đo thời gian từng bước. Thời
gian dừng ghi đo được quyết định hai việc: khung giờ chuyển, và báo trước cho
các cửa hàng bao lâu (5 ngày làm việc, giả định).

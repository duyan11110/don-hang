# 0007. Overlay Kustomize cho repo cấu hình

Trạng thái: Đã chấp nhận
Thay thế: [0005](0005-moi-moi-truong-mot-ban-manifest.md)
Ngày: đề xuất và quyết định trong Sprint 17
Người quyết định: trưởng nhóm
Hạn góp ý: hết tuần đầu Sprint 17

### Bối cảnh

ADR 0005 chọn mỗi môi trường một bản manifest đầy đủ. Lý do của nó không còn
đúng: số service tăng từ api lên thêm Notifications, Payments, RabbitMQ, và
nhiều thay đổi dành cho mọi môi trường (probe, securityContext, NetworkPolicy)
phải sửa hai lần. Đội đã quên một bản ít nhất một lần.

### Các phương án

- Giữ bản đầy đủ: không học gì thêm, tiếp tục trả lãi mỗi thay đổi.
- Kustomize: một base chứa mọi manifest một lần, mỗi môi trường là overlay chỉ
  ghi phần khác. kubectl và Argo CD đọc được Kustomize sẵn, không cần cài thêm.
- Đóng gói Đơn Hàng thành Helm chart: hợp với phần mềm được cài nhiều lần với
  nhiều cấu hình khác nhau; Đơn Hàng chỉ có hai môi trường, chart thêm lớp
  template mà đội không cần.

### Quyết định

Dùng overlay Kustomize cho manifest của chính Đơn Hàng. Phần mềm do người khác
bảo trì, như bộ điều khiển nhận traffic vào cluster, vẫn cài bằng chart mà dự
án của nó phát hành, vì chart đó do họ giữ cho đúng.

Chuyển đổi làm trong một commit (`scripts/k8s/kustomize-config-repo.sh`), kiểm
bằng chỗ khác mà Argo CD báo: chỉ ConfigMap và Deployment của api.

### Hệ quả

- Thay đổi chung sửa một lần trong base; đổi lại, một lỗi trong base đến mọi
  môi trường ở lần sync tiếp theo.
- Muốn biết thứ thật được apply phải render overlay (`kubectl kustomize`); CI
  render mọi overlay rồi kiểm.
- Promote là đổi mục `images` trong overlay production.

### Ý kiến đã nhận

Không có.

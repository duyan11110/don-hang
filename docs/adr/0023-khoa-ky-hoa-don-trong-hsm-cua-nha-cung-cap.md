# 0023. Khóa ký hóa đơn nằm trong dịch vụ HSM của nhà cung cấp

Trạng thái: Đã chấp nhận
Ngày: đề xuất giữa Sprint 22, quyết định cuối Sprint 22
Người quyết định: trưởng nhóm
Hạn góp ý: hết thứ Năm tuần thứ hai Sprint 22

### Bối cảnh

ADR 0015 giữ khóa ký hóa đơn trong một HSM, chỉ Payments được gọi để ký, và
để mở câu hỏi HSM đó chạy ở đâu. ADR 0022 chọn Kubernetes managed của một nhà
cung cấp cho production. Nhà cung cấp đó có dịch vụ quản lý khóa (KMS), trong
đó khóa có thể nằm trong HSM của họ: khóa không bao giờ rời HSM, bên gọi được
phép chỉ gửi dữ liệu cần ký và nhận chữ ký, và mỗi lần dùng khóa được ghi lại.

### Các phương án

- HSM riêng của Đơn Hàng: toàn quyền với phần cứng. Cần thiết bị ở hai nơi để
  không mất khả năng ký khi một nơi hỏng, và người vận hành, nâng cấp, sao lưu
  chúng: đúng loại việc ADR 0022 đã từ chối cho cluster.
- Dịch vụ HSM của nhà cung cấp: khóa trong HSM do nhà cung cấp chạy, Đơn Hàng
  chỉ gọi qua API. Không phần cứng phải lo, nhưng gắn với nhà cung cấp.
- Khóa phần mềm trong dịch vụ quản lý khóa (không HSM): rẻ nhất, nhưng không
  đáp ứng điều ADR 0015 đòi là khóa nằm trong HSM.

### Quyết định

Chọn dịch vụ HSM của nhà cung cấp. Chỉ ServiceAccount của Payments được quyền
ký bằng khóa này; không service, không người nào khác có quyền đó, kể cả trưởng
nhóm, trừ quyền quản trị khóa (tạo, tắt) được tách riêng.

### Hệ quả

- Khóa không rời được HSM, nên rời nhà cung cấp nghĩa là tạo khóa mới và xin
  chứng chỉ mới ở HSM nơi mới. Hóa đơn đã ký trước đó vẫn kiểm được, vì kiểm
  chữ ký chỉ cần public key và chứng chỉ, không cần khóa riêng.
- Secret của cluster production được mã hóa bằng một khóa của cùng dịch vụ
  quản lý khóa (envelope encryption), thay cho khóa `secretbox` nằm trong file
  trên node control plane như ở lab (`scripts/dev-secrets.sh`). Tắt hoặc xóa
  khóa đó thì mọi Secret trong etcd không đọc được, nên quyền tắt, xóa khóa
  được giữ chặt như chính dữ liệu.
- Mỗi lần ký được ghi trong log của dịch vụ quản lý khóa, ngoài mục "ký hóa
  đơn" của nhật ký kiểm toán trong `audit-log.md`.

Điều kiện mở lại:

- Một hợp đồng đòi khóa nằm trong HSM trên máy riêng của Đơn Hàng hoặc của
  khách. Khi đó một ADR mới thay ADR này cho đúng khóa đó, không đổi các khóa
  khác.
- Rời nhà cung cấp của ADR 0022.

### Ý kiến đã nhận

Không có.

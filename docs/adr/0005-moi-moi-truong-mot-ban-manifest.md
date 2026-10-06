# 0005. Mỗi môi trường một bản manifest đầy đủ trong repo cấu hình

Trạng thái: Bị thay thế bởi [0007](0007-overlay-kustomize-cho-repo-cau-hinh.md)
Ngày: quyết định khi lập repo cấu hình đầu tiên, viết lại thành ADR trong
Sprint 16
Người quyết định: trưởng nhóm
Hạn góp ý: không có (viết sau khi đã làm)

ADR này viết sau khi đã làm, theo ADR 0001.

### Bối cảnh

Argo CD đọc repo cấu hình và đưa cluster về đúng những gì repo ghi. Repo cần
chỗ cho hai môi trường, staging và production, khác nhau ở vài giá trị như số
bản sao của api và tag image. Lúc đó đội chưa dùng công cụ nào để sinh
manifest từ một bản chung.

### Các phương án

- Mỗi môi trường một thư mục chép đầy đủ manifest (`envs/staging`,
  `envs/production`): ai đọc cũng hiểu ngay, mỗi file là đúng thứ được apply.
- Một bản chung cộng phần khác nhau của từng môi trường, sinh bằng một công
  cụ: ít chép hơn, nhưng đội phải học công cụ đó trước khi có môi trường đầu
  tiên.

### Quyết định

Chép đầy đủ mỗi môi trường. Đội nhận nợ này có chủ ý: biết cách tốt hơn,
chọn cách nhanh hơn vì chưa có thời gian học công cụ, và biết giá phải trả.

### Hệ quả

- Thay đổi dành cho cả hai môi trường, như một probe mới, phải sửa hai lần;
  quên một bản thì hai môi trường lệch nhau mà không ai thấy.
- Promote là một commit đổi tag trong `envs/production`, diff dễ đọc.

Xem lại khi các thay đổi sửa hai lần bắt đầu thường xuyên. Điều đó đã xảy ra:
ADR 0007 thay thế quyết định này.

### Ý kiến đã nhận

Không có.

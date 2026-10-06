# 0001. Ghi quyết định kiến trúc bằng ADR, trong repo

Trạng thái: Đã chấp nhận
Ngày: đề xuất và quyết định trong Sprint 16
Người quyết định: trưởng nhóm
Hạn góp ý: cuối tuần đầu Sprint 16

### Bối cảnh

Từ stage-3 Đơn Hàng tách thêm service, đổi cách triển khai và chọn một cổng
thanh toán. Lý do của những lựa chọn trước đó nằm rải rác trong tin nhắn,
biên bản họp và mô tả pull request. Người mới vào đội hỏi "vì sao lại thế
này" và không ai trả lời được chắc chắn, vì người quyết định đã quên chi tiết
hoặc đã chuyển sang việc khác.

### Các phương án

- Giữ như hiện tại: lý do nằm trong mô tả pull request và biên bản họp. Không
  tốn gì thêm, nhưng phải biết pull request nào để tìm, và biên bản không đi
  cùng code.
- Một trang wiki chung cho mọi quyết định: dễ sửa, nhưng không được review
  như code, và trang bị sửa dần cho tới khi không còn biết quyết định lúc đầu
  dựa trên điều gì.
- Mỗi quyết định một file ngắn trong `docs/adr/`, đánh số, review qua pull
  request như code.

### Quyết định

Chọn file trong `docs/adr/`. Quy trình viết, góp ý và thay thế ở
`docs/adr/README.md`, mẫu ở `docs/adr/template.md`. Các quyết định quan trọng
đã có từ trước được viết lại thành ADR (0002 tới 0005, 0009, 0010), mỗi file
nói rõ là viết sau khi đã làm.

### Hệ quả

- Mỗi quyết định khó đảo ngược thêm một file phải viết và review.
- ADR viết sau khi đã làm chỉ ghi được những lý do còn nhớ; lý do đã quên thì
  mất.
- Một ADR đã chấp nhận không được sửa nội dung, nên khi quyết định đổi phải
  viết ADR mới thay thế nó.

### Ý kiến đã nhận

Một lập trình viên hỏi có phải viết ADR cho mọi thư viện mới không. Không:
chỉ khi đổi lại tốn kém. Câu trả lời này được đưa vào mục "Khi nào viết một
ADR" của README.

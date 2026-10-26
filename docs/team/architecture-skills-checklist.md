# Bảng tự đánh giá kỹ năng kiến trúc

Quyết định của Đơn Hàng không nằm trong đầu ai: chúng nằm trong một số loại
tài liệu, từ tài liệu yêu cầu tới brief cho lãnh đạo. Bảng này liệt kê các loại
đó, mỗi loại kèm một file ví dụ trong repo, để một người tự đánh giá mình viết
được loại nào tới đâu và chọn việc luyện tiếp. Bảng không nói về chức danh,
lương hay thăng tiến.

### Cách dùng

- Tự chấm, hoặc chấm cùng người kèm trong buổi 1-1 của `mentoring-plan.md`.
- Chấm theo bằng chứng, không theo cảm giác: bằng chứng là một file bạn đã
  viết (trên Đơn Hàng hay trên một hệ thống thật) và những gì xảy ra với nó
  khi người khác đọc.
- Mỗi dòng ở một trong ba bậc:
  - Bậc 1: viết được với mẫu và người kèm.
  - Bậc 2: tự viết một mình, người review không phải viết lại phần nào.
  - Bậc 3: bảo vệ được trước câu phản biện: trả lời được câu hỏi khó về nó,
    bằng driver, số đo hay ADR, không bằng ý thích.
- Bậc 3 quan trọng vì một thiết kế không bảo vệ được là một thiết kế chưa hiểu
  hết. Cột "Câu phản biện để thử" cho mỗi dòng một câu để tự thử bậc đó.

### Bảng kỹ năng

| Số | Loại tài liệu | File ví dụ | Câu phản biện để thử | Bậc đạt |
|---|---|---|---|---|
| KN1 | Tài liệu yêu cầu và yêu cầu phi chức năng | `docs/team/refund-requirements.md` | YC-7 (trả lời trong 2 giây) đo bằng gì, và ai thấy khi nó trượt? | |
| KN2 | Design doc | `docs/design/refund-design.md` | Cổng thanh toán không trả lời trong nhiều phút thì khoản hoàn tiền ở trạng thái nào? | |
| KN3 | ADR | `docs/adr/` (ví dụ 0021) | Phương án bị từ chối hơn phương án được chọn ở điểm nào, và tín hiệu nào làm bạn đổi ý? | |
| KN4 | Đánh giá nhà cung cấp bằng ma trận có trọng số | `docs/team/email-service-evaluation.md` | Đổi trọng số của một tiêu chí thì bên thắng có đổi không? | |
| KN5 | Threat model | `docs/design/threat-model.md` | Người có access token của một khách làm được gì, và điều gì chặn họ? | |
| KN6 | SLO và error budget | `docs/design/slo.md` | Vì sao `429` không tính là xấu mà `503` của `catalog-reads` thì có? | |
| KN7 | Kế hoạch dung lượng | `docs/design/capacity-plan.md` | Số nào trong kế hoạch là số đo, số nào là giả định, và giả định nào sai thì kế hoạch đổi? | |
| KN8 | Runbook | `docs/runbooks/` (ví dụ `product-reads-burn.md`) | Người trực lần đầu gặp alert này có làm theo được mà không phải hỏi ai không? | |
| KN9 | Postmortem | `docs/postmortems/0001-doc-san-pham-tra-503.md` | Action item nào ngăn sự cố lặp lại, cái nào chỉ giúp phát hiện sớm hơn? | |
| KN10 | Review thiết kế | `docs/design/design-review-template.md` và một `*-design-review.md` (ví dụ `support-chat-design-review.md`) | Tải gấp mười thì chỗ nào hỏng trước? | |
| KN11 | Đánh giá kiến trúc | `docs/design/multi-shop-architecture-review.md` | Điểm nhạy nào, khi đổi, kéo hai thuộc tính chất lượng đi ngược nhau? | |
| KN12 | Chiến lược kỹ thuật | `docs/team/technical-strategy.md` | Hành động nào không phục vụ chẩn đoán, và mục "Không làm" nào sẽ bị bỏ nếu một hợp đồng đòi? | |
| KN13 | Roadmap | `docs/team/roadmap.md` | Vì sao mục "Tiếp theo" không có ngày, và dự báo của "Bây giờ" tính từ đâu? | |
| KN14 | Brief cho lãnh đạo | `docs/team/leadership-brief-platform-team.md` | Không làm gì thì mất gì, nói bằng kết quả cửa hàng thấy được? | |
| KN15 | Biện pháp kiểm soát tuân thủ | `docs/team/compliance-controls.md` | Bằng chứng nào do pipeline sinh ra, bằng chứng nào gom tay, và khoảng trống nào người kiểm tra sẽ tìm ra trước? | |

### Chọn bước tiếp theo

- Dòng có bậc thấp nhất chọn việc luyện tiếp, không phải chủ đề thấy thú vị
  nhất. Hai dòng cùng bậc thì chọn dòng mà quyết định sắp tới của bạn cần.
- Bảng file → chủ đề trong `STAGE.md` (mục "What a lesson can learn from each
  new place") nối file ví dụ của dòng đó với chủ đề nó được dùng để học, để
  quay lại đúng chỗ.
- Làm lại bài tập của chủ đề đó trên một bài toán mới, như một tính năng mới
  của Đơn Hàng, thay vì đọc lại: viết lại từ đầu cho thấy dòng yếu ở đâu rõ
  hơn đọc.
- Với một hệ thống thật: viết tài liệu review thiết kế và ADR cho quyết định
  thật kế tiếp, ghi hệ quả mình dự đoán. Một quý sau, so hệ quả đã dự đoán với
  điều đã xảy ra, như buổi xem lại trong
  `docs/design/architecture-health-review.md`.
- Chấm lại sau mỗi tài liệu viết xong, không theo lịch.

### Khoảng trống của lộ trình

Những chủ đề lộ trình học đi cùng repo này cố ý không dạy. Chúng có ích cho
một kiến trúc sư; học chúng ở nơi khác khi một quyết định cần tới.

- Bảo mật ứng dụng ở mức code: injection, XSS. Threat model của Đơn Hàng dừng
  ở ranh giới tin cậy, không đi vào từng lỗ hổng trong code.
- Chủ động gây lỗi trên hệ thống đang chạy để thử độ bền (chaos engineering,
  game day).
- Developer portal cho các đội tự phục vụ, ngoài golden path dạng tài liệu
  (`docs/team/golden-path.md`).
- Policy engine dùng chung cho nhiều loại luật, ngoài admission policy của
  cluster.
- Tự scale theo sự kiện, như theo độ dài queue, ngoài HPA theo CPU.
- Kỹ thuật tìm nguyên nhân gốc có hệ thống, ngoài mục "Yếu tố góp phần" của
  postmortem.

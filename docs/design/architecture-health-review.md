# Xem lại sức khỏe kiến trúc hằng quý

Tài liệu ghi một buổi xem lại sức khỏe kiến trúc của Đơn Hàng, làm mỗi quý
(giả định: buổi đầu tiên, sau Sprint 24). Buổi này hỏi một câu: các quyết định
đã có còn đúng không. Một ADR có thể hết đúng trong khi không ai sửa nó: giả
định bên dưới nó đổi, còn chữ của nó và mọi phép kiểm giữ nó vẫn y nguyên.

Buổi xem lại không quyết lại ADR nào và không viết ADR mới. Nó đọc cạnh nhau
những thứ các đội đã ghi sẵn, và mỗi dòng đọc kết thúc bằng một lựa chọn: giữ,
thêm phép kiểm, đưa vào roadmap, hoặc đề xuất một ADR mới thay ADR cũ. Dòng
chưa có lựa chọn ghi "Mở" để ai cũng thấy. Mọi quan sát và con số dưới đây là
giả định.

Người dự (theo vai trò): vai trò kiến trúc sư (`docs/team/architect-week.md`),
trưởng nhóm, product owner, một người của mỗi đội trong ADR 0025.

### Đầu vào

| Đầu vào | Đọc gì |
|---|---|
| Bảng "Giả định cần theo dõi" của `docs/team/architecture-governance.md` | Tín hiệu mở lại của từng ADR đã xuất hiện chưa |
| Mục "Chưa có phép kiểm tự động" của `fitness-functions.md` | Lựa chọn của từng khoảng trống còn đúng không |
| Mục "Ước lượng lãi và gốc" của `docs/team/tech-debt-register.md` | Món nợ nào đã tới lúc trả |
| SLO và error budget trong `slo.md` | SLI nào tiêu budget nhanh hơn dự tính (giả định: trên staging, không SLI nào hết budget trong quý) |
| `docs/postmortems/` | Action item còn mở, và action item nào chưa có chỗ trong kế hoạch |
| `docs/team/delivery-metrics.md` | Bốn số đo có đổi hướng so với quý trước không (giả định: không) |
| Mục "Rủi ro và câu hỏi mở" của các tài liệu review thiết kế (`*-design-review.md`) | Câu hỏi nào đã quá hạn mà chưa có câu trả lời |

Mọi đầu vào đã có trước buổi họp, nên buổi họp ngắn. Phần việc của vai trò
kiến trúc sư là đọc chúng cạnh nhau: không tài liệu của một đội nào làm việc
đó.

### Giả định cần theo dõi

Mỗi dòng của bảng trong `architecture-governance.md`. Tín hiệu chép từ đó.
"Chưa thấy" là một kết quả đã kiểm, ghi lại, không phải một phỏng đoán.

| ADR | Tín hiệu mở lại | Đã thấy chưa (giả định) | Lựa chọn |
|---|---|---|---|
| 0012 | Một cửa hàng có hợp đồng đòi một bản hệ thống riêng | Chưa thấy: không hợp đồng nào trong quý đòi điều đó | Giữ |
| 0012 | Các đội phải chờ nhau để sửa cùng một module | Chưa thấy: không pull request nào bị chặn vì chờ đội khác | Giữ |
| 0019 | Một cửa hàng cần một bản triển khai riêng | Chưa thấy | Giữ |
| 0019 | Một thay đổi không làm tương thích được với bản trước | Chưa thấy: mọi thay đổi schema của quý qua mục thay đổi schema và message của `backend-review-checklist.md` | Giữ |
| 0019 | Notifications hoặc Payments nhận phần lớn việc qua Gateway | Chưa thấy: HTTPRoute tới hai service đó vẫn chỉ có `/api/v1/refunds` | Giữ |
| 0020 | Hợp đồng đòi RTO hoặc RPO thấp hơn số đo của DR drill | Chưa thấy | Giữ |
| 0020 | Dữ liệu một số cửa hàng phải nằm ở một vùng xác định | Chưa thấy | Giữ |
| 0021 | Hợp đồng đòi mã hóa lời gọi bên trong cluster | Chưa thấy | Giữ |
| 0021 | Service đến từ nhiều nhóm hoặc nhiều ngôn ngữ | Chưa thấy: đã có ba đội nhưng service vẫn là ba service .NET; xem lại khi `DonHang.Support` (ADR 0032) được xây | Giữ |
| 0021 | Service gọi nhau giữa các cluster | Chưa thấy | Giữ |
| 0022 | Hợp đồng đòi máy riêng hoặc dữ liệu ở một nơi xác định | Chưa thấy | Giữ |
| 0022 | Phí nhà cung cấp vượt chi phí giả định của việc tự chạy cluster | Chưa đo được: production chưa chạy trên Kubernetes managed, chưa có hóa đơn | Giữ |
| 0024 | Tỉ lệ email tới hộp thư thấp hơn mức giả định | Chưa đo được: chưa gửi email thật từ production | Giữ |
| 0024 | Giá vượt TCO giả định | Chưa đo được | Giữ |
| 0024 | Dịch vụ A ngừng nhận email qua SMTP | Chưa thấy | Giữ |

Quý này không tín hiệu nào xuất hiện, nên không dòng nào dẫn tới một ADR mới.
Quy tắc khi một tín hiệu xuất hiện: người theo dõi đề xuất một ADR mới thay ADR
cũ; ADR đã chấp nhận không được sửa cho khớp, chỉ được đổi trạng thái thành
`Bị thay thế bởi NNNN` (`docs/adr/README.md`).

Bảng có đủ chưa: so với `docs/adr/README.md`, các ADR "Đã chấp nhận" sau có ghi
điều kiện xem lại hay mở lại nhưng chưa có dòng trong bảng: 0004, 0013, 0014,
0015, 0016, 0017, 0018, 0023, 0025, và 0026 tới 0033. Lựa chọn: thêm dòng, mỗi điều
kiện một dòng chép từ ADR, kèm nơi thấy tín hiệu và người theo dõi.

### Khoảng trống chưa có phép kiểm

Mỗi dòng của mục "Chưa có phép kiểm tự động" trong `fitness-functions.md`.

| Thuộc tính | Lựa chọn đang ghi | Quý này (giả định) | Lựa chọn |
|---|---|---|---|
| Yêu cầu hoàn tiền trả lời trong 2 giây (YC-7) | Theo dõi bằng S4 và alert trên staging | S4 của staging chưa tiêu budget đáng kể; production chưa đo được (mục Khoảng trống đã biết) | Giữ |
| Image đang chạy không mang lỗ hổng công bố sau khi build | Chấp nhận tới khi production nhận khách | Production trên Kubernetes managed đã ở mục "Tiếp theo" của roadmap, nên lý do chấp nhận sắp hết; buổi họp chưa chọn giữa quét theo lịch trong CI và quét image trong registry | Mở |
| Mỗi service chỉ đọc và ghi database của mình (NT1) | Chấp nhận, hỏi trong review; role riêng cho từng service sẽ chặn ở database | Role riêng vẫn ở mục "Sau đó" của roadmap | Giữ |
| Một cửa hàng không đọc được dữ liệu cửa hàng khác | Thêm phép kiểm khi xây row-level security (release 3) | Release 1 đang làm | Giữ |
| Một cửa hàng đông không làm cửa hàng khác bị từ chối | Thêm phép kiểm khi xây giới hạn theo cửa hàng (ADR 0016) | Chưa xây | Giữ |
| Trải nghiệm trên máy khách (A1–A3 của `app-experience.md`) | Theo dõi khi app gửi số đo | Roadmap chưa có mục nào cho việc app gửi số đo | Đưa vào roadmap, mục "Sau đó" |
| Thuộc tính của ADR 0026 tới 0033 | Thêm phép kiểm cùng lúc xây | Chưa ADR nào được xây | Giữ |

### Nợ kỹ thuật

Mỗi món đang mang trong `tech-debt-register.md`, đọc theo mục "Ước lượng lãi và
gốc".

| Món | Lãi mỗi quý, gốc | Quý này (giả định) | Lựa chọn |
|---|---|---|---|
| N2: bảng `payments` cũ còn trong `donhang` | 2 tới 12 giờ; 6 tới 10 giờ | Kế toán chưa xác nhận bước 3 của ADR 0008; lãi vẫn trả ở mỗi câu hỏi "tiền nằm ở bảng nào" | Đưa vào roadmap, phần cố định cho nợ và nền tảng, ngay khi kế toán xác nhận; người theo dõi hỏi lại kế toán trong quý |
| N3: `unitPriceVnd` nhận nhưng bỏ qua | 0,5 tới 1,5 giờ; 40 tới 80 giờ | `/api/v1` chưa có ngày ngừng | Giữ (Chấp nhận) |
| N4: app ghi cứng `localhost` | 1 tới 4 giờ; 16 tới 24 giờ | App chưa được đưa lên cluster | Giữ: trả cùng lần đưa app lên cluster |

### Khoảng trống đã biết

Những khoảng trống mọi người đều biết. Câu hỏi của buổi họp chỉ là: đã có mục
trong `roadmap.md` chưa, và có người phụ trách theo vai trò chưa. Một khoảng
trống ai cũng biết mà không ai phụ trách thì vẫn mở mãi.

| Khoảng trống | Nguồn | Mục trong roadmap | Người phụ trách (vai trò) | Lựa chọn |
|---|---|---|---|---|
| Production chưa có Prometheus: SLO chưa đo được ở production, không alert nào về production | `slo.md`, mục Chưa có | "Tiếp theo": đội biết production đang khỏe (H3) | Lập trình viên phụ trách nền tảng, nay trong đội platform | Giữ |
| Alert của staging chưa gửi tới người trực | `slo.md`, mục Chưa có; action item của postmortem 0001 | Chưa có | Lập trình viên phụ trách nền tảng | Đưa vào roadmap, cùng H3 |
| Bản sao lưu và WAL chưa rời máy chạy database | ADR 0020; TT-4 của `docs/team/compliance-controls.md` | "Bây giờ": base backup và WAL có bản ở region thứ hai (H4) | Lập trình viên phụ trách nền tảng | Giữ |
| Một commit của `gitops-promote.sh` đủ để đưa api lên production: người làm cũng là người duyệt | TT-1 của `compliance-controls.md` | "Tiếp theo": không thay đổi production nào lên mà chỉ một người làm và tự duyệt (H6) | Trưởng nhóm | Giữ |

### Kết quả

| Dòng | Lựa chọn | Người phụ trách (vai trò) | Lần xem lại |
|---|---|---|---|
| Bảng "Giả định cần theo dõi" thiếu các ADR 0004, 0013 tới 0018, 0023, 0025, 0026 tới 0033 | Thêm dòng vào bảng | Trưởng nhóm | Buổi quý sau |
| Image đang chạy không mang lỗ hổng công bố sau build | Mở: chưa chọn cách quét | Lập trình viên phụ trách nền tảng, mang hai cách tới buổi sau | Buổi quý sau, hoặc sớm hơn nếu production nhận khách trước đó |
| Trải nghiệm trên máy khách (A1–A3) | Đưa vào roadmap, mục "Sau đó" | Product owner | Lần xem roadmap kế tiếp |
| N2 | Đưa vào roadmap khi kế toán xác nhận | Lập trình viên backend | Mỗi sprint planning, theo sổ nợ |
| Alert của staging chưa gửi tới người trực | Đưa vào roadmap, cùng H3 | Lập trình viên phụ trách nền tảng | Lần xem roadmap kế tiếp |
| Mọi dòng còn lại | Giữ | Người theo dõi ghi ở từng bảng nguồn | Buổi quý sau |

Không dòng nào dẫn tới đề xuất ADR thay thế trong quý này.

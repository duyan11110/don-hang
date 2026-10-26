# Biện pháp kiểm soát cho yêu cầu của khách hàng ngân hàng

Tài liệu ghi cách Đơn Hàng đáp ứng một danh sách yêu cầu từ bên ngoài, bằng
chứng cho từng điều, và chỗ chưa đáp ứng. Tuân thủ là đáp ứng những yêu cầu do
bên ngoài đặt ra (cơ quan quản lý, hay hợp đồng của một khách lớn) và chỉ ra
được bằng bằng chứng, không chỉ nói là đã làm. Tài liệu này không phải ý kiến
pháp lý.

### Bối cảnh

Một khách hàng là chuỗi cửa hàng thuộc một ngân hàng (giả định) gửi danh sách
yêu cầu trước khi ký hợp đồng:

- TT-1: Mọi thay đổi lên production có một người duyệt khác người làm.
- TT-2: Truy được ai đã làm gì với đơn và với hoàn tiền.
- TT-3: Khóa ký hóa đơn không rời thiết bị bảo vệ khóa.
- TT-4: Sao lưu dữ liệu và thử khôi phục định kỳ, mỗi lần có biên bản.
- TT-5: Biết mọi thành phần phần mềm đang chạy và các lỗ hổng đã biết của
  chúng.
- TT-6: Dữ liệu nằm ở nơi hợp đồng quy định.
- TT-7: Rà soát quyền truy cập định kỳ.

### Bảng kiểm soát

Mỗi yêu cầu được đáp ứng bằng một biện pháp kiểm soát (một cách làm hay một cơ
chế cụ thể), và mỗi biện pháp cần bằng chứng người khác kiểm được. Bảng ghi
đúng hiện trạng ở stage-4.

| Yêu cầu | Biện pháp kiểm soát | Bằng chứng | Sinh tự động hay làm tay | Khoảng trống và kế hoạch |
|---|---|---|---|---|
| TT-1 | Mọi thay đổi production là một commit vào `envs/production` của repo cấu hình; không ai sửa tay trên cluster (NT4 của `architecture-governance.md`) | Lịch sử Git của repo cấu hình: ai commit, lúc nào, đổi gì | Tự động | Trong lab, một commit của `scripts/devops/gitops-promote.sh` là đủ để đưa api lên production: người làm cũng là người duyệt. Kế hoạch: repo cấu hình production bắt buộc pull request có một người duyệt khác tác giả trước khi merge (H6 của `technical-strategy.md`) |
| TT-2 | Nhật ký kiểm toán theo `docs/design/audit-log.md`: mỗi lần giao đơn, yêu cầu hoàn tiền, đổi giá, cấp role, xin ký hóa đơn ghi một entry có chuỗi hash | Chưa có | Sẽ tự động | `audit-log.md` mới là thiết kế, chưa dựng. Hôm nay `requested_by` của dòng hoàn tiền sửa được mà không để lại dấu vết. Kế hoạch: dựng nhật ký theo thiết kế (mục "Sau đó" của `roadmap.md`) |
| TT-3 | Khóa ký hóa đơn nằm trong dịch vụ HSM của nhà cung cấp, chỉ ServiceAccount của Payments được ký (ADR 0015, 0023) | ADR 0015, 0023; khi dựng: log mỗi lần dùng khóa của dịch vụ quản lý khóa | Sẽ tự động | Đã quyết, chưa dựng: stage-4 chưa có hóa đơn, chưa có HSM, chỉ có sample với khóa phần mềm cho lab |
| TT-4 | Dump logic, base backup và WAL lưu liên tục; thử khôi phục bằng `scripts/devops/restore-test.sh`; dựng lại staging bằng `scripts/devops/dr-drill.sh` | Output của `restore-test.sh` (số dòng so với lúc dump, thời gian khôi phục) và của `dr-drill.sh` (thời gian từng bước) | Script tự chạy, nhưng được khởi động bằng tay, chưa theo lịch | Bản sao lưu và WAL chưa rời máy đang chạy database (ADR 0020). Kế hoạch: sao sang region thứ hai (H4), chạy thử khôi phục theo lịch và lưu output làm biên bản |
| TT-5 | Mỗi lần chạy `ci.yml` viết SBOM cho từng image và quét lỗ hổng trên SBOM đó; lỗ hổng mức High hoặc Critical đã có bản sửa làm hỏng lần chạy, trừ những lỗ hổng `.grype.yaml` chấp nhận kèm lý do. Image được đẩy từ master còn được ký và có attestation về nguồn build và SBOM | SBOM (artifact `sboms` của lần chạy), kết quả quét trong log của lần chạy, chữ ký và attestation lưu cạnh image; `scripts/devops/verify-image.sh` kiểm chữ ký và nguồn build | Tự động | SBOM và kết quả quét giữ theo thời hạn lưu artifact của lần chạy; image của các thành phần tự chạy trong `self-run-components.md` không đi qua `ci.yml`. Kế hoạch: lưu SBOM của mỗi bản đã lên production cùng commit deploy |
| TT-6 | Đơn Hàng chạy ở một region (ADR 0020), trên Kubernetes managed của một nhà cung cấp (ADR 0022) | ADR 0020, 0022 | Làm tay | Hợp đồng đòi dữ liệu ở một nơi xác định là điều kiện mở lại của ADR 0022 và ADR 0020 (bảng "Giả định cần theo dõi" của `architecture-governance.md`): ký hợp đồng này thì mở lại hai ADR đó trước |
| TT-7 | Chưa có | Chưa có | Chưa có | Chưa ai rà soát role trong Keycloak hay quyền trên repo cấu hình theo lịch. Kế hoạch: rà soát mỗi quý, xuất danh sách role và người có quyền làm biên bản (mục "Sau đó" của `roadmap.md`) |

### Nguyên tắc

- Bằng chứng do pipeline sinh ra trên mỗi thay đổi (SBOM, kết quả quét, chữ
  ký, lịch sử Git) được ưu tiên hơn bằng chứng gom tay trước một lần kiểm tra:
  nó rẻ hơn và khó làm giả hơn.
- Khoảng trống được ghi ra kèm kế hoạch, không giấu. Một khoảng trống người
  kiểm tra tìm ra trước tốn nhiều lòng tin hơn một khoảng trống đội đã tự ghi.

# Bốn số đo phát hành của Đơn Hàng

Bốn số đo này đến từ một chương trình nghiên cứu dài hạn về cách các đội phần
mềm phát hành (thường gọi là DORA metrics). Đội Đơn Hàng dùng chúng để biết
phát hành nhanh hơn có phải trả bằng nhiều sự cố hơn không. Tài liệu ghi cách
Đơn Hàng đếm từng số, lấy dữ liệu ở đâu và số đo không cho biết điều gì.
`scripts/devops/delivery-metrics.sh` tính cả bốn số từ lịch sử của một repo
cấu hình; trong lab, lịch sử đó là một quý giả định với ngày cố định.

### Bốn số đo

| Số đo | Đơn Hàng đếm thế nào | Đo điều gì |
|---|---|---|
| Tần suất deploy | Số commit đổi image ở `envs/production` của repo cấu hình, mỗi tuần | Tốc độ |
| Lead time for changes | Từ thời điểm commit ứng dụng (commit mà tag `sha-` của image trỏ tới) tới commit deploy image đó lên production; báo cáo trung vị | Tốc độ |
| Change failure rate | Phần các deploy về sau bị coi là hỏng: bị revert, hoặc có bản ghi sự cố trỏ tới | Độ ổn định |
| Thời gian khôi phục | Từ commit deploy hỏng tới commit đưa production về một bản chạy tốt (revert hoặc bản sửa) | Độ ổn định |

Lead time dùng trung vị chứ không dùng trung bình: một thay đổi nằm chờ cả
tháng sẽ kéo trung bình lên mà không nói gì về các thay đổi còn lại.

### Nguồn dữ liệu

- Repo cấu hình: mỗi commit đổi image ở `envs/production` là một deploy, theo
  cách `scripts/devops/gitops-promote.sh` promote. Commit `git revert` của
  một deploy đánh dấu deploy đó hỏng và là thời điểm khôi phục.
- Repo Đơn Hàng: thời điểm của commit ứng dụng mà tag `sha-` trỏ tới, để tính
  lead time.
- Bản ghi sự cố (`docs/postmortems/`): sự cố được sửa không bằng revert, như
  một bản sửa lỗi đi tiếp, hay một cấu hình sửa trên cluster. Bản ghi cho biết
  deploy nào gây ra và lúc nào dịch vụ trở lại bình thường.

`delivery-metrics.sh` chỉ đọc `git log`, nên chỉ thấy phần thứ nhất và thứ
hai.

### Giới hạn

- Lịch sử Git chỉ thấy lỗi được sửa bằng revert. Sự cố sửa cách khác chỉ có
  trong bản ghi sự cố; thiếu bản ghi thì change failure rate thấp hơn thật.
- Thời gian khôi phục tính từ lúc deploy, không từ lúc khách bắt đầu gặp lỗi.
  Bản ghi sự cố có mốc thời gian chính xác hơn khi có.
- Một quý ít deploy cho số đo dao động mạnh: hai deploy hỏng trong mười deploy
  đã là 20%. Đội đọc xu hướng qua nhiều quý, không đọc một con số lẻ.
- Đội không so số đo của mình với mức của nghiên cứu hay của đội khác: cách
  đếm khác nhau thì con số không so được.

### Đọc bốn số cùng nhau

Hai số tốc độ và hai số ổn định được đọc cùng nhau. Deploy nhiều hơn mỗi tuần
trong khi change failure rate tăng không phải là tiến bộ. Change failure rate
thấp nhờ deploy mỗi tháng một lần cũng không: mỗi bản phát hành khi đó gom
nhiều thay đổi, khó tìm thay đổi nào gây lỗi.

### Không dùng để đánh giá cá nhân

Bốn số đo mô tả hệ thống phát hành (pipeline, review, test, cách deploy),
không mô tả từng người. Chúng không được dùng để xếp hạng hay đánh giá lập
trình viên. Dùng như vậy thì người ta sẽ chỉnh con số thay vì chỉnh hệ thống,
ví dụ chia một thay đổi thành nhiều deploy cho tần suất đẹp hơn, hoặc không
ghi bản ghi sự cố.

Đội xem bốn số mỗi quý, cùng các bản ghi sự cố của quý đó.

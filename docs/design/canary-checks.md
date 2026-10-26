# Kiểm tra canary khi phát hành api

Trạng thái: đang dùng từ stage-4. ADR 0019 chọn canary qua Gateway cho api;
tài liệu này ghi các bước và giới hạn của canary đó. Các giới hạn được viết
trước khi bản phát hành bắt đầu, và không ai đổi chúng trong lúc đang phát
hành. Mọi con số trong file này là giả định: đội đặt chúng theo lượng request
của staging hiện nay và xem lại khi có số đo của production.

### Các bước

Canary là Deployment `api-canary` chạy bản mới. HTTPRoute `api` chia request
giữa Service `api` (bản đang chạy, gọi là bản stable) và Service `api-canary`
theo trọng số: mỗi Service nhận phần bằng trọng số của nó chia cho tổng.

| Bước | Trọng số `api` | Trọng số `api-canary` | Canary phải phục vụ trước khi xét |
|---|---|---|---|
| 1 | 90 | 10 | 200 request (giả định) |
| 2 | 50 | 50 | 200 request (giả định) |
| 3 | 0 | 100 | 200 request (giả định) |

Mỗi bước là một commit đổi trọng số trong repo cấu hình; Argo CD áp commit đó
như mọi thay đổi khác. Trong lab, `scripts/devops/canary-steps.sh` làm các
commit này.

### Vì sao phải đợi đủ số request

Một bước chỉ được xét khi canary đã phục vụ đủ số request tối thiểu của bước
đó. Với ít request, một lỗi lẻ đã là một tỉ lệ lớn: sau 20 request, một lỗi
là 5%; sau 200 request, cùng một lỗi là 0,5%. Xét sớm hơn thì quyết định
dựa vào may rủi chứ không dựa vào bản mới.

Thời gian không thay cho số request: một bước để mười phút lúc vắng khách có
thể chỉ có vài chục request.

### Giới hạn 5xx

Canary qua một bước khi tỉ lệ `5xx` của nó, tính trên các request của bước
đó, không vượt tỉ lệ `5xx` của bản stable trong cùng khoảng thời gian quá 1
điểm phần trăm (giả định). Ví dụ: bản stable có 0,2% `5xx` thì canary được
tới 1,2%.

Canary được so với bản stable chứ không so với 0, vì lỗi của thứ cả hai bản
cùng dùng (PostgreSQL, Redis, Keycloak) chạm cả hai bản như nhau; chỉ phần
chênh lệch mới nói về bản mới.

Hai tỉ lệ đọc từ Prometheus của staging: counter
`http_requests_received_total` của prometheus-net, chia theo nhãn `code` và
nhãn `app` mà Prometheus chép từ Pod (`api` hoặc `api-canary`).

### Quyết định ở mỗi bước

- Trong giới hạn: commit trọng số của bước kế tiếp.
- Vượt giới hạn: commit trọng số `api-canary` về 0 ngay, không chờ hỏi ai.
  Bản stable vẫn chạy đủ số Pod nên nhận lại toàn bộ request; chỉ những
  request canary đã phục vụ là gặp lỗi.
- Sát giới hạn (cách giới hạn dưới 0,5 điểm phần trăm, giả định): không lên
  bước. Canary phục vụ thêm 200 request rồi xét lại. Vẫn sát thì người phát
  hành quyết; khi còn nghi ngờ, người phát hành dừng.

Người phát hành là lập trình viên mở bản phát hành đó. Người đang trực được
dừng canary bất cứ lúc nào, không cần hỏi người phát hành.

### Khi canary qua bước 3

Ở trọng số 100, canary đã nhận mọi request và qua giới hạn. Đội chuyển bản mới
thành bản stable bằng hai commit:

1. Đổi image của Deployment `api` sang đúng digest canary đang chạy (không
   build lại image), rồi đợi rolling update của `api` xong.
2. Đặt trọng số về `api` 100, `api-canary` 0, và bỏ Deployment `api-canary`.

Bản phát hành sau bắt đầu lại từ bước 1 với một `api-canary` mới.

### Nối với error budget

Mỗi request canary trả `5xx` được tính vào error budget của api trong
`slo.md` như mọi request khác. Dừng sớm vì thế tiêu ít budget: phần budget mất
chỉ bằng số request lỗi canary đã phục vụ.

Khi budget của api đã hết, chính sách trong `slo.md` chỉ cho phát hành bản sửa
lỗi. Bản sửa lỗi vẫn đi đủ ba bước ở trên: một bản sửa hỏng sẽ tiêu thêm vào
budget đã hết.

### Phạm vi

Tài liệu này chỉ áp cho api, thành phần nhận request qua Gateway.
Notifications và Payments phát hành bằng rolling update (ADR 0019). Đội không
dùng controller chạy canary tự động trong cluster: mỗi bước là một commit, nên
lịch sử repo cấu hình cho biết bước nào chạy lúc nào và ai quyết.

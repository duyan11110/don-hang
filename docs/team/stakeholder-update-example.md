# Bên liên quan của luồng hoàn tiền và bản cập nhật gửi họ

Cùng một kế hoạch (`refund-plan-example.md`), mỗi bên cần biết một phần khác.
Đội Đơn Hàng lập bảng này ở Sprint 15 planning và xem lại cùng sổ rủi ro.

## Ai cần biết gì

| Bên liên quan | Quan tâm điều gì | Đội cần gì từ họ | Báo khi nào, bằng cách nào |
|---|---|---|---|
| Chăm sóc khách hàng | Khi nào khách tự yêu cầu hoàn tiền được, để bớt cuộc gọi | Người xử lý yêu cầu bị cổng thanh toán từ chối; những câu khách hay hỏi về hoàn tiền | Email ngắn sau mỗi sprint review, và ngay khi dự báo đổi |
| Kế toán | Đối soát thay đổi gì; mỗi khoản hoàn tiền do ai yêu cầu, lúc nào | Mẫu danh sách hoàn tiền họ cần, trước cuối Sprint 15 | Một buổi 30 phút trong Sprint 15, sau đó email khi có thay đổi |
| Bên cung cấp cổng thanh toán | Đội gọi API hoàn tiền đúng cách và với lượng yêu cầu bao nhiêu | Tài khoản môi trường test trong tuần đầu Sprint 15; câu trả lời về idempotency key và thời hạn hoàn tiền | Email kỹ thuật khi cần |
| Product owner | Toàn bộ kế hoạch: phạm vi, dự báo, rủi ro | Quyết định phạm vi; hỏi các bên ngoài đội những câu còn mở | Sprint planning, sprint review, và daily khi có vướng |
| Bộ phận vận hành | Đơn `shipped` khách từ chối nhận có được hoàn tiền không | Câu trả lời cho câu hỏi đó, dù đợt này chưa làm | Qua product owner, trước Sprint 16 |

## Bản cập nhật gửi chăm sóc khách hàng (sau Sprint 15 planning)

> Chào anh chị bên chăm sóc khách hàng,
>
> Khách sẽ tự yêu cầu hoàn tiền cho đơn đã thanh toán ngay trong ứng dụng, dự
> kiến trong khoảng tuần thứ 8 đến tuần thứ 10 kể từ tuần này. Đây là một
> khoảng, chưa phải một ngày; chúng tôi sẽ báo anh chị ngay khi khoảng này đổi.
>
> Điều có thể làm chậm: phần kết nối với cổng thanh toán là việc chúng tôi chưa
> làm bao giờ. Tuần này chúng tôi thử trước với cổng thanh toán, nên tuần sau sẽ
> biết rõ hơn.
>
> Chúng tôi cần anh chị hai việc trước cuối tuần sau:
> 1. Chọn một người nhận các yêu cầu hoàn tiền bị cổng thanh toán từ chối, để
>    gọi lại cho khách như anh chị vẫn làm.
> 2. Gửi chúng tôi năm câu khách hay hỏi nhất về hoàn tiền, để email gửi khách
>    trả lời sẵn những câu đó.
>
> Trong lúc chờ, khách gọi xin hoàn tiền vẫn được xử lý như hiện nay.

Bản này không có chữ "sprint", "story point" hay "velocity": người nhận không
dùng những chữ đó. Nếu sau tuần thử với cổng thanh toán dự báo đổi, đội gửi bản
cập nhật mới ngay trong ngày, không đợi tới tuần thứ 8.

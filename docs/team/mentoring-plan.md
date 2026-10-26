# Kế hoạch kèm một lập trình viên mới

Kèm (mentoring) ở Đơn Hàng là một mối quan hệ kéo dài: một người có kinh
nghiệm giúp một người ít kinh nghiệm hơn lớn lên qua việc thật, câu hỏi và
phản hồi, không phải bằng cách đưa sẵn câu trả lời. Kế hoạch dưới đây dùng cho
mỗi lập trình viên mới vào đội. Mọi khoảng thời gian là giả định; người kèm và
người mới đổi nhịp khi cần.

### Tuần đầu

- Chạy lab trên máy mình bằng `scripts/up.sh`, theo `STAGE.md`.
- Đọc `STAGE.md` và danh sách ADR ở `docs/adr/README.md`: biết hệ thống có
  những phần nào và vì sao chúng có hình dạng hôm nay.
- Merge một thay đổi nhỏ (sửa một dòng tài liệu, một test còn thiếu) qua đủ
  các bước thường lệ: pull request, CI, review.

### Ba bậc

Người mới đi qua ba bậc trên việc thật của sprint, mỗi bậc ít nhất một việc:

1. Làm cặp với người kèm: hai người cùng một màn hình, người mới cầm bàn phím
   phần lớn thời gian.
2. Tự làm, có review kỹ: người mới làm một mình, người kèm review kỹ hơn
   thường lệ và giải thích lý do của mỗi nhận xét, theo cách
   `review-comments-examples.md` ghi.
3. Sở hữu một thay đổi tới khi phát hành: từ story tới production, gồm canary
   (`docs/design/canary-checks.md`) và release note.

Lên bậc khi người kèm và người mới cùng thấy bậc hiện tại đã quen, không theo
số tuần.

### Khi người mới bị kẹt

Người kèm hỏi trước: "Bạn đã xem ở đâu rồi?". Rồi trỏ tới nơi giữ câu trả lời,
như một ADR, một runbook trong `docs/runbooks/` hay một tài liệu thiết kế, trước
khi tự đưa câu trả lời. Người mới học được câu trả lời nằm ở đâu, và lần sau
không cần hỏi.

Quyết định được giải thích trong ADR và trong nhận xét review là cách một người
kèm giúp được nhiều người hơn mình kèm trực tiếp: người khác đọc lý do và tự ra
quyết định tiếp theo mà không cần hỏi.

### Trực sự cố

Trực theo cùng ba bước, như `on-call-staffing.md` yêu cầu: một ca đi theo
người trực, một ca trực chính có người thứ hai được chỉ định, rồi vào vòng
trực.

### Thời gian của người kèm

Kèm người là việc đội lập kế hoạch, không phải việc làm thêm sau giờ. Trong
thời gian kèm, người kèm nhận ít việc sprint hơn (giả định: bớt khoảng một phần
năm), và đội tính phần đó khi chọn việc cho sprint.

Mỗi tuần một buổi 1-1 ba mươi phút giữa người kèm và người mới. Phản hồi đi hai
chiều: người mới cũng nói điều gì trong cách kèm đang giúp và điều gì không.

### Chọn việc tiếp theo

Ở buổi 1-1 sau mỗi việc đã xong, hai người chọn việc tiếp theo cùng nhau:

- Việc chạm tới phần hệ thống người mới chưa sửa lần nào, để số người sửa được
  mỗi phần trong `team-structure.md` tăng lên.
- Việc luyện loại tài liệu ở dòng có bậc thấp nhất của người mới trong
  `architecture-skills-checklist.md`.

Kế hoạch này không nói về lộ trình thăng tiến hay lương; những việc đó không
thuộc tài liệu của đội.

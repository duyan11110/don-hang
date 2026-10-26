# Thiết kế: đưa `shop_id` vào dữ liệu qua ba lần phát hành

Trạng thái: kế hoạch, chưa làm ở stage-4: không có migration hay code nào
dưới đây trong repo. Thực hiện ADR 0013 (bảng chung, `shop_id`, row-level
security). Mỗi lần phát hành để lại một schema mà code của lần phát hành
trước vẫn chạy được, nên quay lui là deploy lại phiên bản trước.

### Bảng nhận `shop_id`

| Database | Bảng nhận `shop_id` | Không nhận, vì sao |
|---|---|---|
| `donhang` | `customers`, `orders`, `order_items`, `order_status_history` (Ordering); `products` (Catalog) | `outbox_messages`, `inbox_messages`: dòng kỹ thuật, relay đọc của mọi cửa hàng, cửa hàng nằm trong thân message; bảng `payments` cũ: chờ xóa (ADR 0008) |
| `donhang_payments` | `payments` | `outbox_messages`, `inbox_messages`, như trên |
| `donhang_notifications` | `notifications` | `inbox_messages`, như trên |

Bảng `shops` nằm trong `donhang`, chủ là Ordering. Payments và Notifications
lưu `shop_id` như một con số, không có khóa ngoại tới database khác.

### Release 1: thêm cột, chưa ai dùng

1. Tạo `shops`, thêm cửa hàng hôm nay làm cửa hàng 1.
2. Thêm `shop_id integer NOT NULL DEFAULT 1` vào mọi bảng ở trên. Với
   PostgreSQL 17, một default là hằng số không ghi lại bảng: dòng cũ nhận giá
   trị 1 mà không giữ khóa lâu.
3. Khóa ngoại tới `shops` thêm với `NOT VALID` (chỉ kiểm dòng mới), rồi
   `VALIDATE CONSTRAINT` trong một migration riêng, không chặn ghi.
4. Index bắt đầu bằng `shop_id` (ví dụ `orders (shop_id, customer_id)`) tạo
   bằng `CREATE INDEX CONCURRENTLY`, ngoài transaction
   (`suppressTransaction: true`), với `SET lock_timeout`.
5. Index unique mới `customers (shop_id, email)` tạo cùng cách; index unique
   cũ trên `email` vẫn giữ.

Quay lui: code trước release 1 không biết các cột mới, mọi dòng nó ghi nhận
default 1.

### Release 2: code biết cửa hàng

1. Access token mang cửa hàng của người gọi (claim `shop_id`, Keycloak thêm
   vào); API và Payments lấy cửa hàng từ đó, không từ tham số của client.
2. Code ghi `shop_id` vào mọi dòng mới và lọc mọi truy vấn theo nó.
3. Message `order.*` và `payment.*` thêm thuộc tính tùy chọn `shopId`;
   Payments và Notifications lưu `shopId` nhận được, thiếu thì dùng 1, vì
   message dạng cũ còn trong outbox và hàng đợi.
4. Khi mọi Pod đã chạy code release 2, một migration riêng bỏ default của
   `shop_id` và bỏ index unique cũ trên `email`. Từ đó không dòng mới nào
   nhận cửa hàng 1 do sơ ý.

Quay lui: trước bước 4, deploy lại release 1 vẫn chạy (default còn). Sau bước
4, chỉ quay lui về release 2.

### Release 3: row-level security và role riêng

1. Mỗi request đặt cửa hàng của nó bằng `SET LOCAL app.shop_id` trong
   transaction của request; consumer đặt theo `shopId` của message. Bước này
   chạy được cả khi chưa bật policy.
2. Bật row-level security trên các bảng ở trên, policy
   `shop_id = current_setting('app.shop_id', true)::integer`.
3. Mỗi service chuyển sang role PostgreSQL riêng, không phải superuser, không
   `BYPASSRLS`, chỉ có quyền trên database của mình; mỗi service một user
   RabbitMQ riêng, chỉ có quyền trên exchange và hàng đợi của mình (phát hiện
   P1, P2 của `threat-model.md`).
4. Job nền đọc dòng đến hạn của mọi cửa hàng (gửi email, gửi hoàn tiền) chạy
   bằng một role riêng, có policy cho phép đọc mọi dòng chỉ trên bảng của job
   đó.

Quay lui: tắt row-level security trên bảng và trả connection string về role
cũ; code release 3 vẫn chạy vì nó vẫn lọc theo `shop_id`.

### Câu hỏi còn mở

Kế hoạch giả định mỗi tài khoản Keycloak thuộc một cửa hàng. Nếu một khách mua
ở nhiều cửa hàng bằng một tài khoản (ngoài phạm vi của
`multi-shop-requirements.md`), cửa hàng của request phải lấy từ nơi khác, và
release 2 phải xem lại.

-- Fixed data for the lab: 8 products, 5 customers (one of whom never ordered),
-- 12 orders. Every id is written out so that every lesson sees the same rows.
SET TIME ZONE 'Asia/Ho_Chi_Minh';

INSERT INTO products (id, name, price_vnd) VALUES
    (1, 'Bàn phím cơ',        1250000),
    (2, 'Chuột không dây',     450000),
    (3, 'Tai nghe',            890000),
    (4, 'Màn hình 24 inch',   3200000),
    (5, 'Giá đỡ laptop',       320000),
    (6, 'Ổ cứng SSD 512GB',   1450000),
    (7, 'Webcam 720p',         560000),
    (8, 'Đèn bàn LED',         280000);

-- lesson: foundation.l1.sql-write
INSERT INTO customers (id, full_name, email, city) VALUES
    (1, 'Trần Minh Anh',   'anh.tran@example.com',   'Hà Nội'),
    (2, 'Nguyễn Bảo Châu', 'chau.nguyen@example.com', 'Đà Nẵng'),
    (3, 'Lê Quốc Dũng',    'dung.le@example.com',    'Hồ Chí Minh'),
    (4, 'Phạm Thu Hà',     'ha.pham@example.com',    'Hải Phòng'),
    (5, 'Vũ Gia Khánh',    'khanh.vu@example.com',   'Cần Thơ');

INSERT INTO orders (id, customer_id, placed_at, status) VALUES
    ( 1, 1, '2026-03-02 09:15:00+07', 'paid'),
    ( 2, 1, '2026-03-05 14:40:00+07', 'shipped'),
    ( 3, 2, '2026-03-05 08:05:00+07', 'paid'),
    ( 4, 2, '2026-03-11 19:20:00+07', 'cancelled'),
    ( 5, 3, '2026-03-12 10:00:00+07', 'paid'),
    ( 6, 3, '2026-03-13 05:30:00+07', 'new'),
    ( 7, 3, '2026-03-18 07:45:00+07', 'shipped'),
    ( 8, 4, '2026-03-19 16:10:00+07', 'paid'),
    ( 9, 4, '2026-03-21 11:25:00+07', 'new'),
    (10, 1, '2026-03-25 20:55:00+07', 'paid'),
    (11, 2, '2026-03-28 13:05:00+07', 'shipped'),
    (12, 4, '2026-03-31 06:20:00+07', 'new');

INSERT INTO order_items (order_id, product_id, quantity, unit_price_vnd) VALUES
    ( 1, 1, 1, 1250000), ( 1, 2, 2,  450000),
    ( 2, 3, 1,  890000),
    ( 3, 4, 1, 3200000), ( 3, 5, 1,  320000),
    ( 4, 6, 1, 1450000),
    ( 5, 2, 1,  450000), ( 5, 8, 2,  280000),
    ( 6, 7, 1,  560000),
    ( 7, 1, 1, 1250000), ( 7, 3, 1,  890000),
    ( 8, 4, 2, 3200000),
    ( 9, 5, 1,  320000),
    (10, 6, 1, 1450000), (10, 8, 1,  280000),
    (11, 2, 3,  450000),
    (12, 7, 1,  560000), (12, 1, 1, 1250000);

INSERT INTO payments (id, order_id, paid_at, amount_vnd, method) VALUES
    (1,  1, '2026-03-02 09:20:00+07', 2150000, 'card'),
    (2,  2, '2026-03-05 14:45:00+07',  890000, 'card'),
    (3,  3, '2026-03-05 08:10:00+07', 3520000, 'bank_transfer'),
    (4,  5, '2026-03-12 10:05:00+07', 1010000, 'cod'),
    (5,  7, '2026-03-18 07:50:00+07', 2140000, 'card'),
    (6,  8, '2026-03-19 16:15:00+07', 6400000, 'bank_transfer'),
    (7, 10, '2026-03-25 21:00:00+07', 1730000, 'card'),
    (8, 11, '2026-03-28 13:10:00+07', 1350000, 'cod');

INSERT INTO notifications (id, order_id, channel, sent_at, subject) VALUES
    (1, 1, 'email', '2026-03-02 09:16:00+07', 'Đơn hàng 1 đã được tạo'),
    (2, 1, 'email', '2026-03-02 09:21:00+07', 'Đơn hàng 1 đã thanh toán'),
    (3, 2, 'sms',   '2026-03-05 14:46:00+07', 'Đơn hàng 2 đang giao'),
    (4, 3, 'email', '2026-03-05 08:11:00+07', 'Đơn hàng 3 đã thanh toán'),
    (5, 4, 'email', '2026-03-11 19:25:00+07', 'Đơn hàng 4 đã bị hủy'),
    (6, 8, 'sms',   '2026-03-19 16:16:00+07', 'Đơn hàng 8 đã thanh toán');

-- The tables above were filled with explicit ids, so move each identity
-- sequence past them; otherwise the next INSERT without an id would collide.
SELECT setval(pg_get_serial_sequence('products', 'id'), 8);
SELECT setval(pg_get_serial_sequence('customers', 'id'), 5);
SELECT setval(pg_get_serial_sequence('orders', 'id'), 12);
SELECT setval(pg_get_serial_sequence('payments', 'id'), 8);
SELECT setval(pg_get_serial_sequence('notifications', 'id'), 6);

-- donhang_tenancy, layout 1: shared tables. Every shop's rows sit in the
-- same tables, told apart by a shop_id column. scripts/backend/tenancy-db.sh
-- runs this file; Đơn Hàng's own database stays single-shop.
CREATE TABLE shops (
    id   integer PRIMARY KEY,
    name text    NOT NULL
);

-- lesson: backend.l3.tenant-isolation-models
-- shop_id comes first in every key and index: a query for one shop reads
-- only that shop's part of each index, each shop numbers its own rows from
-- 1, and an order can only point at a customer of the same shop.
CREATE TABLE customers (
    shop_id   integer NOT NULL REFERENCES shops (id),
    id        integer NOT NULL,
    full_name text    NOT NULL,
    PRIMARY KEY (shop_id, id)
);

CREATE TABLE orders (
    shop_id     integer     NOT NULL REFERENCES shops (id),
    id          integer     NOT NULL,
    customer_id integer     NOT NULL,
    placed_at   timestamptz NOT NULL,
    status      text        NOT NULL,
    PRIMARY KEY (shop_id, id),
    FOREIGN KEY (shop_id, customer_id) REFERENCES customers (shop_id, id)
);
CREATE INDEX orders_shop_id_customer_id ON orders (shop_id, customer_id);

INSERT INTO shops (id, name) VALUES
    (1, 'Cửa hàng Hà Nội'),
    (2, 'Cửa hàng Đà Nẵng');

INSERT INTO customers (shop_id, id, full_name) VALUES
    (1, 1, 'Trần Minh Anh'),
    (1, 2, 'Lê Thu Hà'),
    (2, 1, 'Nguyễn Văn Bình'),
    (2, 2, 'Phạm Thị Lan');

INSERT INTO orders (shop_id, id, customer_id, placed_at, status) VALUES
    (1, 1, 1, '2026-03-02 09:15+07', 'paid'),
    (1, 2, 2, '2026-03-02 10:40+07', 'new'),
    (1, 3, 1, '2026-03-03 14:05+07', 'shipped'),
    (2, 1, 1, '2026-03-02 11:20+07', 'paid'),
    (2, 2, 2, '2026-03-04 08:55+07', 'new');

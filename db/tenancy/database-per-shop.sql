-- Layout 3: a database per shop. scripts/backend/tenancy-db.sh runs this
-- file in donhang_shop_1 with shop=1 and in donhang_shop_2 with shop=2: the
-- same orders table in each database, holding only that shop's orders.
CREATE TABLE orders (
    id          integer     PRIMARY KEY,
    customer_id integer     NOT NULL,
    placed_at   timestamptz NOT NULL,
    status      text        NOT NULL
);

INSERT INTO orders (id, customer_id, placed_at, status)
SELECT id, customer_id, placed_at::timestamptz, status
FROM (VALUES
    (1, 1, 1, '2026-03-02 09:15+07', 'paid'),
    (1, 2, 2, '2026-03-02 10:40+07', 'new'),
    (1, 3, 1, '2026-03-03 14:05+07', 'shipped'),
    (2, 1, 1, '2026-03-02 11:20+07', 'paid'),
    (2, 2, 2, '2026-03-04 08:55+07', 'new')
) AS shop_orders (shop_id, id, customer_id, placed_at, status)
WHERE shop_id = :shop;

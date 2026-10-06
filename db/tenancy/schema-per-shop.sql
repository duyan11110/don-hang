-- donhang_tenancy, layout 2: a schema per shop. Schemas shop_1 and shop_2
-- each hold their own orders table, with no shop_id column: the session's
-- search_path decides which shop's orders a query reads.
-- lesson: backend.l3.tenant-isolation-models
CREATE SCHEMA shop_1;
CREATE TABLE shop_1.orders (
    id          integer     PRIMARY KEY,
    customer_id integer     NOT NULL,
    placed_at   timestamptz NOT NULL,
    status      text        NOT NULL
);

CREATE SCHEMA shop_2;
CREATE TABLE shop_2.orders (LIKE shop_1.orders INCLUDING ALL);

-- The same orders as the shared tables, split by shop.
INSERT INTO shop_1.orders (id, customer_id, placed_at, status) VALUES
    (1, 1, '2026-03-02 09:15+07', 'paid'),
    (2, 2, '2026-03-02 10:40+07', 'new'),
    (3, 1, '2026-03-03 14:05+07', 'shipped');

INSERT INTO shop_2.orders (id, customer_id, placed_at, status) VALUES
    (1, 1, '2026-03-02 11:20+07', 'paid'),
    (2, 2, '2026-03-04 08:55+07', 'new');

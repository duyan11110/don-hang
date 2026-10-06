-- orders_by_month in donhang_perf: the same 200,000 orders as its orders
-- table, partitioned by month of placed_at (January to May 2026, which is
-- every order fill.sql writes). scripts/backend/partition-pruning.sh runs
-- this file, so it starts again from scratch on every run.
DROP TABLE IF EXISTS orders_by_month;

-- lesson: backend.l3.table-partitioning
-- The parent table holds no rows: each row goes to the partition whose
-- range contains its placed_at. The primary key has to include placed_at,
-- the partition key, so (id, placed_at) instead of id alone.
CREATE TABLE orders_by_month (
    id          integer     NOT NULL,
    customer_id integer     NOT NULL,
    placed_at   timestamptz NOT NULL,
    status      text        NOT NULL,
    PRIMARY KEY (id, placed_at)
) PARTITION BY RANGE (placed_at);

CREATE TABLE orders_2026_01 PARTITION OF orders_by_month
    FOR VALUES FROM ('2026-01-01 00:00+07') TO ('2026-02-01 00:00+07');
CREATE TABLE orders_2026_02 PARTITION OF orders_by_month
    FOR VALUES FROM ('2026-02-01 00:00+07') TO ('2026-03-01 00:00+07');
CREATE TABLE orders_2026_03 PARTITION OF orders_by_month
    FOR VALUES FROM ('2026-03-01 00:00+07') TO ('2026-04-01 00:00+07');
CREATE TABLE orders_2026_04 PARTITION OF orders_by_month
    FOR VALUES FROM ('2026-04-01 00:00+07') TO ('2026-05-01 00:00+07');
CREATE TABLE orders_2026_05 PARTITION OF orders_by_month
    FOR VALUES FROM ('2026-05-01 00:00+07') TO ('2026-06-01 00:00+07');

INSERT INTO orders_by_month (id, customer_id, placed_at, status)
SELECT id, customer_id, placed_at, status FROM orders;

CREATE INDEX orders_by_month_customer_id ON orders_by_month (customer_id);
VACUUM ANALYZE orders_by_month;

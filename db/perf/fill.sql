-- Rows for donhang_perf, the large copy of the Đơn Hàng schema that
-- scripts/backend/perf-db.sh builds from the EF Core migrations. 20 customers,
-- 200,000 orders: customer 1 is a large business buyer with 81% of them, the
-- other 19 have 1% each (2,000 orders). Every value is computed from the row
-- number, nothing is random, so every machine gets exactly the same rows.
INSERT INTO customers (id, full_name, email, city)
SELECT g, 'Khách ' || lpad(g::text, 2, '0'), 'perf-' || g || '@example.com', 'Hà Nội'
FROM generate_series(1, 20) AS g;

INSERT INTO orders (id, customer_id, placed_at, status)
SELECT g,
       CASE WHEN g % 100 < 81 THEN 1 ELSE g % 100 - 79 END,
       timestamptz '2026-01-01 00:00:00+07' + g * interval '1 minute',
       CASE g % 7
           WHEN 0 THEN 'cancelled'
           WHEN 1 THEN 'new'
           WHEN 2 THEN 'new'
           WHEN 3 THEN 'paid'
           WHEN 4 THEN 'paid'
           ELSE 'shipped'
       END
FROM generate_series(1, 200000) AS g;

SELECT setval(pg_get_serial_sequence('customers', 'id'), 20);
SELECT setval(pg_get_serial_sequence('orders', 'id'), 200000);

-- ANALYZE normally reads a random sample of 30,000 rows, so its estimates
-- move a little between runs. Asking for statistics this detailed makes it
-- read every row: the plans the lessons print are the same on every run.
ALTER TABLE orders ALTER COLUMN id SET STATISTICS 10000;
ALTER TABLE orders ALTER COLUMN customer_id SET STATISTICS 10000;
ALTER TABLE orders ALTER COLUMN status SET STATISTICS 10000;
VACUUM ANALYZE customers;
VACUUM ANALYZE orders;

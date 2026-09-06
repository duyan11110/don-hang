-- Why one query is fast and another slow. COSTS OFF prints the shape of the
-- plan without the estimated numbers, so the answer is about the index alone.
SET max_parallel_workers_per_gather = 0;

CREATE TEMPORARY TABLE order_log AS
SELECT g AS id,
       (g % 5) + 1 AS customer_id,
       timestamptz '2026-01-01 00:00:00+07' + (g * interval '1 minute') AS placed_at
FROM generate_series(1, 200000) AS g;
ANALYZE order_log;

-- lesson: foundation.l1.sql-index-intro
EXPLAIN (COSTS OFF)
SELECT * FROM order_log WHERE placed_at = '2026-01-02 03:04:00+07';

CREATE INDEX order_log_placed_at_idx ON order_log (placed_at);
ANALYZE order_log;

EXPLAIN (COSTS OFF)
SELECT * FROM order_log WHERE placed_at = '2026-01-02 03:04:00+07';

-- The index cannot help once a function is applied to the indexed column.
EXPLAIN (COSTS OFF)
SELECT * FROM order_log WHERE date(placed_at) = '2026-01-02';

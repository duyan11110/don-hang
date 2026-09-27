-- Which index serves one customer's next page of orders, on donhang_perf
-- (scripts/backend/perf-db.sh). The query is the inner SELECT of the SQL
-- EF Core sends for ListByCustomerAsync (scripts/backend/efcore-sql.sh), with
-- its parameters filled in: customer 7, the page after order 120000, 20 rows.
-- ANALYZE without timings or costs: only what each step did, the same on
-- every run.
SET max_parallel_workers_per_gather = 0;
SET jit = off;

-- lesson: backend.l2.composite-indexes
-- With IX_orders_customer_id_id on (customer_id, id): the plan starts in the
-- index at customer 7, order 120000, reads in id order and stops after 20.
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT o.id, o.customer_id, o.status
FROM orders AS o
WHERE o.customer_id = 7 AND o.id > 120000
ORDER BY o.id
LIMIT 20;

-- lesson: backend.l2.composite-indexes
-- A condition on the first column alone still narrows the search.
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT count(*) FROM orders WHERE customer_id = 7;

-- lesson: backend.l2.composite-indexes
-- The same page with only the stage-1 index on customer_id: no index gives
-- customer 7's orders in id order, so the plan walks the primary key from
-- 120000 and throws away other customers' rows. DDL in PostgreSQL is
-- transactional, so the rollback puts the indexes back.
BEGIN;
DROP INDEX "IX_orders_customer_id_id";
CREATE INDEX "IX_orders_customer_id" ON orders (customer_id);
ANALYZE orders;

EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT o.id, o.customer_id, o.status
FROM orders AS o
WHERE o.customer_id = 7 AND o.id > 120000
ORDER BY o.id
LIMIT 20;

ROLLBACK;

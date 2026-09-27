-- Reading a query plan, on donhang_perf (scripts/backend/perf-db.sh): the
-- Đơn Hàng tables with 200,000 orders — 81% of them customer 1's, 2,000
-- for each of the other 19 customers.
-- One process per query, and no compiling of plans to machine code, so the
-- plans below are the same on every machine.
SET max_parallel_workers_per_gather = 0;
SET jit = off;

-- lesson: backend.l2.indexes-and-plans
-- EXPLAIN only plans the query. Each step: cost=<before the first row>..<for
-- all rows>, in the planner's own units, and the rows it expects.
EXPLAIN
SELECT id, status FROM orders WHERE customer_id = 7;

-- EXPLAIN ANALYZE really runs it, and adds what happened: time in
-- milliseconds, the rows each step really returned, and how many loops.
EXPLAIN ANALYZE
SELECT id, status FROM orders WHERE customer_id = 7;

-- lesson: backend.l2.indexes-and-plans
-- A plan is a tree. Each step takes rows from the more indented steps under
-- it; the top line's figures are for the whole query.
EXPLAIN
SELECT c.full_name, count(*) AS orders
FROM orders AS o
JOIN customers AS c ON c.id = o.customer_id
WHERE o.id <= 1000
GROUP BY c.full_name;

-- lesson: backend.l2.indexes-and-plans
-- Customer 1 has most of the rows, so reading the whole table in order is
-- the cheapest plan: a sequential scan is the right choice here, even though
-- an index on customer_id exists.
EXPLAIN
SELECT id, status FROM orders WHERE customer_id = 1;

-- lesson: backend.l2.indexes-and-plans
-- Statistics come from ANALYZE. A copy of one customer's orders, analyzed,
-- then given a second customer's orders without analyzing again: the
-- estimate still describes the table as it was.
CREATE TEMPORARY TABLE orders_copy AS SELECT * FROM orders WHERE customer_id = 7;
ANALYZE orders_copy;
INSERT INTO orders_copy SELECT * FROM orders WHERE customer_id = 8;

EXPLAIN ANALYZE
SELECT * FROM orders_copy WHERE customer_id = 8;

ANALYZE orders_copy;

EXPLAIN ANALYZE
SELECT * FROM orders_copy WHERE customer_id = 8;

-- lesson: backend.l2.indexes-and-plans
-- EXPLAIN ANALYZE on an UPDATE really updates. Inside a transaction that is
-- rolled back, nothing it changed survives.
SELECT count(*) AS cancelled_before FROM orders_copy WHERE status = 'cancelled';

BEGIN;
EXPLAIN ANALYZE
UPDATE orders_copy SET status = 'cancelled' WHERE customer_id = 8;
ROLLBACK;

SELECT count(*) AS cancelled_after_rollback FROM orders_copy WHERE status = 'cancelled';

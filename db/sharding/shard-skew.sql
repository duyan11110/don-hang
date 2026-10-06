-- Where donhang_perf's 200,000 orders would land with 4 shards, for two
-- shard keys. Nothing is moved: each query only counts.
-- scripts/backend/shard-skew.sh runs this file.

-- lesson: backend.l3.sharding
-- By customer: all of one customer's orders land on one shard, so customer
-- 1, who placed 81% of them, takes that shard with them.
SELECT customer_id % 4 AS shard,
       count(*) AS orders,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS percent
FROM orders
GROUP BY customer_id % 4
ORDER BY shard;

-- By order id: consecutive ids take turns, so the shards come out even,
-- but one customer's orders are spread over all four.
SELECT id % 4 AS shard,
       count(*) AS orders,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS percent
FROM orders
GROUP BY id % 4
ORDER BY shard;

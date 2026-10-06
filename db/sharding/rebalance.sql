-- Going from 4 shards to 5 with donhang_perf's 200,000 orders, by order id:
-- first with shard = id % N, then with a shard map of 64 buckets. Nothing
-- is moved: each query only counts. scripts/backend/rebalance-shards.sh
-- runs this file.

-- lesson: backend.l3.rebalancing-shards
-- With shard = id % N, an order moves when id % 4 and id % 5 differ.
SELECT count(*) FILTER (WHERE id % 4 <> id % 5) AS orders_that_move,
       count(*) AS orders,
       round(100.0 * count(*) FILTER (WHERE id % 4 <> id % 5) / count(*), 1) AS percent
FROM orders;

-- The shard map: id % 64 picks a bucket, and the map says which shard
-- holds each bucket. To start with, the 4 shards hold 16 buckets each.
CREATE TEMP TABLE shard_map (
    bucket integer PRIMARY KEY,
    shard  integer NOT NULL
);
INSERT INTO shard_map (bucket, shard)
SELECT bucket, bucket % 4 FROM generate_series(0, 63) AS bucket;

-- lesson: backend.l3.rebalancing-shards
-- Adding shard 4 changes 12 rows of the map, 3 buckets from each old
-- shard. Only the orders in those 12 buckets move; no other order changes
-- shard, because no other bucket did.
UPDATE shard_map SET shard = 4 WHERE bucket < 12;

SELECT count(*) FILTER (WHERE shard_map.shard = 4) AS orders_that_move,
       count(*) AS orders,
       round(100.0 * count(*) FILTER (WHERE shard_map.shard = 4) / count(*), 1) AS percent
FROM orders
JOIN shard_map ON shard_map.bucket = orders.id % 64;

-- Where everything is after the change.
SELECT shard_map.shard,
       count(DISTINCT shard_map.bucket) AS buckets,
       count(*) AS orders
FROM orders
JOIN shard_map ON shard_map.bucket = orders.id % 64
GROUP BY shard_map.shard
ORDER BY shard_map.shard;

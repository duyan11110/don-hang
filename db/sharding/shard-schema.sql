-- The orders table of each lab shard, donhang_shard_0 and donhang_shard_1:
-- the same table in every shard. scripts/backend/shard-split.sh runs this
-- file; the indexes serve the two queries of ShardedOrders.
CREATE TABLE orders (
    id          integer     PRIMARY KEY,
    customer_id integer     NOT NULL,
    placed_at   timestamptz NOT NULL,
    status      text        NOT NULL
);
CREATE INDEX orders_customer_id_placed_at ON orders (customer_id, placed_at DESC, id DESC);
CREATE INDEX orders_placed_at ON orders (placed_at DESC, id DESC);

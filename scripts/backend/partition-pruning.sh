#!/usr/bin/env bash
# Copy donhang_perf's orders into orders_by_month, partitioned by month, and compare the plans of a query by month and by customer.
set -euo pipefail
# donhang_perf is built from the host (perf-db.sh drives docker compose); the
# queries then run inside the lab box.
if [ ! -f /.dockerenv ]; then
  built=$("$(dirname "$0")/perf-db.sh" --if-missing 2>&1) || { echo "$built" >&2; exit 1; }
  exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"
fi

PGOPTIONS='-c client_min_messages=warning' \
  psql --host db --username donhang --dbname donhang_perf --no-psqlrc --quiet \
       --set ON_ERROR_STOP=on --file /repo/db/partitioning/orders-by-month.sql

sql() {
  psql --host db --username donhang --dbname donhang_perf --no-psqlrc \
       --echo-queries --pset footer=off --command "$1"
}

echo "== rows in each partition"
sql "SELECT tableoid::regclass AS partition, count(*) FROM orders_by_month GROUP BY 1 ORDER BY 1"

# lesson: backend.l3.table-partitioning
# COSTS OFF: only the shape of the plan, which is what matters here.
echo "== March's orders: a condition on placed_at, the partition key"
sql "EXPLAIN (COSTS OFF) SELECT count(*) FROM orders_by_month
WHERE placed_at >= '2026-03-01 00:00+07' AND placed_at < '2026-04-01 00:00+07'"
echo "== one customer's orders: no condition on placed_at"
sql "EXPLAIN (COSTS OFF) SELECT count(*) FROM orders_by_month WHERE customer_id = 7"

echo "== a primary key without the partition key"
sql "CREATE TABLE orders_by_month_id_only (id integer PRIMARY KEY, placed_at timestamptz NOT NULL)
PARTITION BY RANGE (placed_at)" || true
echo

# lesson: backend.l3.table-partitioning
# Removing January: two quick statements on the table's structure, instead
# of a DELETE that finds and removes January's rows one by one.
echo "== remove January"
sql "ALTER TABLE orders_by_month DETACH PARTITION orders_2026_01"
sql "DROP TABLE orders_2026_01"
sql "SELECT min(placed_at), count(*) FROM orders_by_month"

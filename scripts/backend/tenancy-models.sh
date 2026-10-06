#!/usr/bin/env bash
# Read shop 2's orders in three layouts (shared tables, a schema per shop, a database per shop), then add one column to each.
set -euo pipefail
# The lab databases are built from the host (tenancy-db.sh drives docker
# compose); the queries then run inside the lab box.
if [ ! -f /.dockerenv ]; then
  built=$("$(dirname "$0")/tenancy-db.sh" --if-missing 2>&1) || { echo "$built" >&2; exit 1; }
  exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"
fi

sql() {
  psql --host db --username donhang --no-psqlrc --echo-queries --pset footer=off "$@"
}

# lesson: backend.l3.tenant-isolation-models
echo "== shared tables: every query names its shop"
sql --dbname donhang_tenancy --command \
  "SELECT id, customer_id, status FROM orders WHERE shop_id = 2 ORDER BY id"
echo "== a schema per shop: search_path picks the shop"
sql --dbname donhang_tenancy --command "SET search_path TO shop_2" --command \
  "SELECT id, customer_id, status FROM orders ORDER BY id"
echo "== a database per shop: the connection picks the shop"
sql --dbname donhang_shop_2 --command \
  "SELECT id, customer_id, status FROM orders ORDER BY id"

echo "== one query over two shops' databases"
sql --dbname donhang_shop_1 --command \
  "SELECT count(*) FROM orders JOIN donhang_shop_2.public.orders AS other USING (id)" || true
echo

# Adding a column, each inside a transaction that is rolled back, so the
# next run starts from the same tables.
alter() {
  local db=$1 table=$2
  psql --host db --username donhang --dbname "$db" --no-psqlrc --quiet --set ON_ERROR_STOP=on \
       --command "BEGIN" \
       --command "ALTER TABLE $table ADD COLUMN gift_note text" \
       --command "ROLLBACK"
  echo "  $db: ALTER TABLE $table ADD COLUMN gift_note text"
}
echo "== add a gift_note column to the orders of every shop"
echo "shared tables, 1 ALTER TABLE:"
alter donhang_tenancy public.orders
echo "a schema per shop, 1 ALTER TABLE per shop:"
alter donhang_tenancy shop_1.orders
alter donhang_tenancy shop_2.orders
echo "a database per shop, 1 ALTER TABLE per shop:"
alter donhang_shop_1 orders
alter donhang_shop_2 orders

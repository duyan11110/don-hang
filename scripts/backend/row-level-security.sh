#!/usr/bin/env bash
# Turn on row-level security for donhang_tenancy's orders and query them as donhang, then as shop_app with and without a shop set.
set -euo pipefail
# The lab databases are built from the host (tenancy-db.sh drives docker
# compose); the queries then run inside the lab box.
if [ ! -f /.dockerenv ]; then
  built=$("$(dirname "$0")/tenancy-db.sh" --if-missing 2>&1) || { echo "$built" >&2; exit 1; }
  exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"
fi

psql --host db --username donhang --dbname donhang_tenancy --no-psqlrc --quiet \
     --set ON_ERROR_STOP=on --file /repo/db/tenancy/row-level-security.sql

# --echo-queries prints each statement before its result; an error does not
# stop psql here, because two of them are the point.
sql() {
  psql --host db --username donhang --dbname donhang_tenancy --no-psqlrc \
       --echo-queries --pset footer=off --command "$1"
}

echo "== as donhang, a superuser: the policy does not apply"
sql "SELECT shop_id, count(*) FROM orders GROUP BY shop_id ORDER BY shop_id"

echo "== as shop_app, before any shop is set"
sql "SET ROLE shop_app; SELECT count(*) FROM orders"

# lesson: backend.l3.row-level-security
# What a request does on a pooled connection: set the shop inside its own
# transaction, with SET LOCAL, so it is gone when the transaction ends and
# the next request on this connection starts with no shop at all.
echo "== as shop_app, inside a transaction for shop 1"
sql "SET ROLE shop_app;
BEGIN;
SET LOCAL app.shop_id = '1';
SELECT shop_id, id, status FROM orders ORDER BY id;
COMMIT;
SELECT current_setting('app.shop_id', true) AS shop_after_commit, count(*) FROM orders;"

echo "== as shop_app for shop 1, insert an order of shop 2"
sql "SET ROLE shop_app;
BEGIN;
SET LOCAL app.shop_id = '1';
INSERT INTO orders (shop_id, id, customer_id, placed_at, status)
VALUES (2, 3, 1, now(), 'new');
ROLLBACK;" || true
echo

echo "== a table with row-level security and no policy: customers"
sql "BEGIN;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
SET LOCAL ROLE shop_app;
SET LOCAL app.shop_id = '1';
SELECT count(*) FROM customers;
ROLLBACK;"

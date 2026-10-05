#!/usr/bin/env bash
# While a psql session ships order 5, cancel it through the api: the xmin check turns the lost update into a 409.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

base=http://localhost:8080/api/v1
source "$(dirname "$0")/../lib/keycloak.sh"
# set_order_5 <status>. From stage-3 Order.Cancel() refuses a paid order
# (its money goes back through a refund), so the script starts order 5 at
# `new`, which may be cancelled, and puts back the seed's `paid` at the end.
set_order_5() {
  psql --host db --username donhang --dbname donhang --no-psqlrc --quiet \
       --command "UPDATE orders SET status = '$1' WHERE id = 5"
}
set_order_5 new

# Order 5 belongs to customer 3.
token=$(keycloak_access_token dung.le@example.com)

ship=$(mktemp)
trap 'rm -f "$ship"' EXIT

# lesson: backend.l2.optimistic-concurrency
# The ship session changes order 5 and holds its row lock for 2 seconds. The
# api reads order 5 meanwhile (still new, old xmin), Order.Cancel() allows
# it, and EF Core's UPDATE ... WHERE id = 5 AND xmin = <old value> waits for
# the lock. Once ship commits, xmin has changed: the UPDATE matches no row.
psql --host db --username donhang --dbname donhang --no-psqlrc --echo-queries \
     --set ON_ERROR_STOP=on > "$ship" 2>&1 <<'SQL' &
BEGIN;
UPDATE orders SET status = 'shipped' WHERE id = 5;
\! sleep 2
COMMIT;
SQL
sleep 0.5

echo "== PATCH /api/v1/orders/5/cancel, sent while the ship session holds the row"
curl -sS -w '\n  -> %{http_code}\n' -X PATCH "$base/orders/5/cancel" -H "Authorization: Bearer $token"
wait

echo "== ship session"; cat "$ship"
echo "== order 5 afterwards"
psql --host db --username donhang --dbname donhang --no-psqlrc \
     --command "SELECT id, status FROM orders WHERE id = 5"
set_order_5 paid

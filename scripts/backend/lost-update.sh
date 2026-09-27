#!/usr/bin/env bash
# Two sessions under Read Committed both read order 5 as paid; ship commits first, cancel overwrites it: a lost update.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

session() {
  psql --host db --username donhang --dbname donhang \
       --no-psqlrc --echo-queries --set ON_ERROR_STOP=on "$@"
}
reset_order_5() {
  psql --host db --username donhang --dbname donhang --no-psqlrc --quiet \
       --command "UPDATE orders SET status = 'paid' WHERE id = 5"
}
reset_order_5

ship=$(mktemp); cancel=$(mktemp)
trap 'rm -f "$ship" "$cancel"' EXIT

# lesson: backend.l2.transactions-in-practice
# Each session reads, waits, then writes — like a request that loads the
# order, checks its status in C#, and saves. `\! sleep` pauses between steps.
session > "$ship" 2>&1 <<'SQL' &
BEGIN;
SHOW transaction_isolation;
SELECT status FROM orders WHERE id = 5;
\! sleep 1
UPDATE orders SET status = 'shipped' WHERE id = 5;
\! sleep 2
COMMIT;
SQL
sleep 0.5
session > "$cancel" 2>&1 <<'SQL'
BEGIN;
SHOW transaction_isolation;
SELECT status FROM orders WHERE id = 5;
\! sleep 1
\echo '-- this UPDATE waits for the row lock the ship session holds'
UPDATE orders SET status = 'cancelled' WHERE id = 5;
COMMIT;
SQL
wait

echo "== ship session (started first)"; cat "$ship"
echo "== cancel session (started 0.5 s later)"; cat "$cancel"
echo "== order 5 afterwards"
session --command "SELECT id, status FROM orders WHERE id = 5"
reset_order_5

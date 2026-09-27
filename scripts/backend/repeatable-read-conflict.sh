#!/usr/bin/env bash
# The lost update again, with the cancel session under Repeatable Read: its UPDATE fails with 40001 instead.
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
# Ship is the same as in lost-update.sh. Cancel reads and writes in one
# Repeatable Read snapshot, so PostgreSQL refuses to write over a row that
# changed after that snapshot was taken.
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
session --set ON_ERROR_STOP=off > "$cancel" 2>&1 <<'SQL'
BEGIN ISOLATION LEVEL REPEATABLE READ;
SHOW transaction_isolation;
SELECT status FROM orders WHERE id = 5;
\! sleep 1
\echo '-- this UPDATE waits for the row lock the ship session holds, then fails'
UPDATE orders SET status = 'cancelled' WHERE id = 5;
\echo 'SQLSTATE:' :LAST_ERROR_SQLSTATE
ROLLBACK;
SQL
wait

echo "== ship session (started first)"; cat "$ship"
echo "== cancel session (started 0.5 s later)"; cat "$cancel"
echo "== order 5 afterwards"
session --command "SELECT id, status FROM orders WHERE id = 5"
reset_order_5

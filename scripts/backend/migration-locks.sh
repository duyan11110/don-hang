#!/usr/bin/env bash
# On the 200,000 orders of donhang_perf: a plain CREATE INDEX blocks writes but not reads, CONCURRENTLY refuses a transaction block, and an ALTER TABLE behind a long transaction makes later queries wait.
set -euo pipefail
# donhang_perf is built from the host (scripts/backend/perf-db.sh, which
# needs docker); everything after that runs inside the lab box.
if [ ! -f /.dockerenv ]; then
  "$(dirname "$0")/perf-db.sh" --if-missing
  exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"
fi

# session <name> <sql>: one psql session, named so pg_stat_activity can find it.
session() {
  PGAPPNAME=$1 psql --host db --username donhang --dbname donhang_perf --no-psqlrc --quiet --set VERBOSITY=terse \
    --tuples-only --no-align --command "$2"
}
# until_state <name> <wait_event>: wait until that session waits on that event.
until_state() {
  for _ in $(seq 300); do
    [ "$(session watcher "SELECT count(*) FROM pg_stat_activity
           WHERE application_name = '$1' AND wait_event = '$2'")" = 1 ] && return 0
    sleep 0.1
  done
  echo "session $1 never waited on $2" >&2
  return 1
}
# end <name>: end a session that is still sleeping in its transaction (it rolls back).
end() { session watcher "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE application_name = '$1'" >/dev/null; }
tmp=$(mktemp -d)
cleanup() {
  end A; end B; end C
  session cleanup "DROP INDEX IF EXISTS orders_status_idx; ALTER TABLE orders DROP COLUMN IF EXISTS note" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

# lesson: backend.l4.migration-locks
# Session A builds a plain index inside a transaction and keeps it open:
# the lock CREATE INDEX took on orders stays until A ends. B can still read;
# B's INSERT would wait for A, and lock_timeout gives up after 2 seconds.
echo "== 1. A: BEGIN; CREATE INDEX orders_status_idx ON orders (status); (transaction left open)"
session A "BEGIN; CREATE INDEX orders_status_idx ON orders (status); SELECT pg_sleep(60);" >/dev/null 2>&1 &
until_state A PgSleep
echo "B: SELECT count(*) FROM orders -> $(session B "SELECT count(*) FROM orders")"
echo "B: SET lock_timeout = '2s'; INSERT INTO orders ..."
session B "SET lock_timeout = '2s';
  INSERT INTO orders (customer_id, placed_at, status) VALUES (1, now(), 'new')" 2>&1 | sed 's/^/  /' || true
end A
wait

echo "== 2. CREATE INDEX CONCURRENTLY inside a transaction block"
session A "BEGIN; CREATE INDEX CONCURRENTLY orders_status_idx ON orders (status); COMMIT;" 2>&1 | sed 's/^/  /' || true
echo "and on its own"
session A "CREATE INDEX CONCURRENTLY orders_status_idx ON orders (status)" && echo "  created"
session A "DROP INDEX orders_status_idx"

# lesson: backend.l4.migration-locks
# A has read orders in a transaction it keeps open. B's ALTER TABLE needs the
# strongest lock, so it waits for A; C's plain SELECT, arriving after B,
# waits behind B, although A would let it read. B gives up at its
# lock_timeout, and only then does C get its answer.
echo "== 3. A: BEGIN; SELECT count(*) FROM orders; (transaction left open)"
session A "BEGIN; SELECT count(*) FROM orders; SELECT pg_sleep(60);" >/dev/null 2>&1 &
until_state A PgSleep
echo "B: SET lock_timeout = '5s'; ALTER TABLE orders ADD COLUMN note text"
session B "SET lock_timeout = '5s'; ALTER TABLE orders ADD COLUMN note text" > "$tmp/b" 2>&1 &
b=$!
until_state B relation
echo "C: SELECT count(*) FROM orders"
session C "SELECT count(*) FROM orders" > "$tmp/c" 2>&1 &
c=$!
until_state C relation && echo "  C waits for a lock, behind B: yes"
wait "$b" || true
sed 's/^/  B: /' "$tmp/b"
wait "$c"
echo "  C, once B gave up: $(cat "$tmp/c")"
end A
wait

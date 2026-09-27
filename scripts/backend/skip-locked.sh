#!/usr/bin/env bash
# Two sessions claim pending notifications the way NotificationQueue does: with SKIP LOCKED each gets different rows.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

sql() {
  psql --host db --username donhang --dbname donhang --no-psqlrc --quiet --tuples-only --no-align "$@"
}

# Four demo jobs, due on 1 January 2100: the api's own NotificationSender,
# which asks for rows due by now, leaves them alone. The claims below ask
# for rows due by that date instead, and see only these four.
due=2100-01-01T00:00:00Z
sql --command "INSERT INTO notifications (order_id, channel, subject, status, attempts, created_at, next_attempt_at)
               SELECT 1, 'email', 'demo job ' || n, 'pending', 0, now(), '$due' FROM generate_series(1, 4) AS n"
trap "sql --command \"DELETE FROM notifications WHERE next_attempt_at = '$due'\"" EXIT

# lesson: backend.l2.skip-locked-claiming
# The WHERE, ORDER BY and locking clause of NotificationQueue.ClaimDueAsync;
# each session below sends it in a transaction of its own.
claim="SELECT subject FROM notifications
       WHERE status = 'pending' AND next_attempt_at <= '$due'
       ORDER BY next_attempt_at, id LIMIT 2"

echo "== session A: BEGIN, claim 2 rows FOR UPDATE SKIP LOCKED, hold the locks for 3 s"
session_a=$(mktemp)
sql --command "BEGIN" --command "$claim FOR UPDATE SKIP LOCKED" \
    --command "SELECT pg_sleep(3)" --command "COMMIT" > "$session_a" &
sleep 1
grep -v '^$' "$session_a" | sed 's/^/  A got: /'

echo "== session B, while A holds its locks: the same claim"
sql --command "BEGIN" --command "$claim FOR UPDATE SKIP LOCKED" --command "COMMIT" | sed 's/^/  B got: /'

echo "== session C: the claim without SKIP LOCKED, giving up after 1 s of waiting"
sql --command "SET lock_timeout = '1s'" --command "BEGIN" --command "$claim FOR UPDATE" \
    --command "COMMIT" 2>&1 | sed 's/^/  C: /' || true

echo "== session D: a plain SELECT, no FOR UPDATE: it waits for nothing"
sql --command "SELECT subject FROM notifications WHERE next_attempt_at = '$due' ORDER BY id" | sed 's/^/  D sees: /'
wait # for session A to commit
rm -f "$session_a"

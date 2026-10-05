#!/usr/bin/env bash
# Try the first phase of two-phase commit in Đơn Hàng's PostgreSQL: PREPARE TRANSACTION, which it refuses.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

# lesson: backend.l3.two-phase-commit
# A participant in two-phase commit must be able to prepare: write down its
# changes, keep its locks, and promise to commit later if told to. In
# PostgreSQL that is PREPARE TRANSACTION, and it is off unless
# max_prepared_transactions is above 0, which by default it is not. The
# refused PREPARE ends the transaction, so the UPDATE never takes effect.
psql --host db --username donhang --dbname donhang --no-psqlrc --echo-queries \
     --set ON_ERROR_STOP=off <<'SQL'
SHOW max_prepared_transactions;
BEGIN;
UPDATE orders SET status = 'refunding' WHERE id = 1;
PREPARE TRANSACTION 'refund-order-1';
SELECT status FROM orders WHERE id = 1;
SQL

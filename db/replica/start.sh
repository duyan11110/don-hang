#!/bin/sh
# Runs inside db-replica (Compose profile replica) as user postgres: copy db once, then follow it as a read-only standby.
set -eu

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  # lesson: backend.l3.read-replicas
  # A copy of the whole db server. --write-recovery-conf adds standby.signal
  # and how to reach db, so the server below starts as a standby: it streams
  # every later change from db, applies it, and refuses writes.
  pg_basebackup --host db --username donhang --pgdata "$PGDATA" \
                --write-recovery-conf --wal-method stream --checkpoint fast
  chmod 700 "$PGDATA"
fi

# The lab replica waits 5 s before it applies each committed change, so
# scripts/backend/replica-lag.sh sees the same stale read on every run. A
# real replica has no such wait: its lag is whatever load and network make it.
exec postgres -c recovery_min_apply_delay=5s

#!/bin/sh
# Runs inside db-pitr (Compose profile pitr): unpack the base backup once, then recover to RECOVERY_TARGET_TIME.
set -eu

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  # The data files of the whole db server as scripts/devops/base-backup.sh
  # copied them, and the WAL written while it copied.
  tar -xzf /backups/base/base.tar.gz -C "$PGDATA"
  tar -xzf /backups/base/pg_wal.tar.gz -C "$PGDATA/pg_wal"
  # recovery.signal: start by replaying WAL, not as a normal server.
  touch "$PGDATA/recovery.signal"
fi

# lesson: devops.l3.point-in-time-recovery
# restore_command fetches each archived WAL segment that db's archive_command
# gzipped. Replay stops before the first transaction that committed after
# RECOVERY_TARGET_TIME; "pause" then keeps the server read-only right there,
# so the rows of that moment can be read and copied back.
# (The image's entrypoint hands the files to user postgres and starts the
# server as that user; it runs no initdb, since PG_VERSION is there.)
exec docker-entrypoint.sh postgres \
  -c restore_command='gunzip < /wal-archive/%f.gz > %p' \
  -c recovery_target_time="$RECOVERY_TARGET_TIME" \
  -c recovery_target_action=pause

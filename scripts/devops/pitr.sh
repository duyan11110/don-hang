#!/usr/bin/env bash
# Delete order 3's items by mistake, recover the server as it was just before into db-pitr, and copy the rows back to db.
# Runs on the host: it starts db-pitr (Compose profile pitr) with docker compose.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1

on_db() { docker compose exec -T db psql --username donhang --dbname donhang --no-psqlrc "$@"; }
on_pitr() { docker compose exec -T db-pitr psql --username donhang --dbname donhang --no-psqlrc "$@"; }
value() { on_db --tuples-only --no-align --command "$1"; }
items_of_order_3="SELECT * FROM order_items WHERE order_id = 3 ORDER BY product_id"

# Recovery starts from a base backup taken before the mistake.
if ! docker compose exec -T lab test -f /backups/base/base.tar.gz; then
  made=$(scripts/devops/base-backup.sh 2>&1) || { echo "$made" >&2; exit 1; }
fi

# A safety net for the lab, not part of the lesson: should this script stop
# before the rows are back, the copy taken here puts them back.
saved=$(value "COPY ($items_of_order_3) TO STDOUT")
put_back_if_missing() {
  if [ "$(value "SELECT count(*) FROM order_items WHERE order_id = 3")" = "0" ]; then
    printf '%s\n' "$saved" | on_db --quiet --command "COPY order_items FROM STDIN"
  fi
}

echo "== order 3's items on db"
on_db --command "$items_of_order_3"
target=$(value "SELECT clock_timestamp()")
echo "recovery_target_time = $target"
sleep 1

# lesson: devops.l3.point-in-time-recovery
# The mistake: meant for one item, run for the whole order. Recovery will
# go back to $target, a moment before it. pg_switch_wal() closes the current
# WAL segment so it is archived now, not after archive_timeout.
echo "== the mistake, a second later"
on_db --command "DELETE FROM order_items WHERE order_id = 3"
segment=$(value "SELECT pg_walfile_name(pg_switch_wal())")
for _ in $(seq 60); do
  [ "$(value "SELECT last_archived_wal >= '$segment' FROM pg_stat_archiver")" = "t" ] && break
  sleep 1
done

echo "== recover into db-pitr, up to the moment before the DELETE"
docker compose --profile pitr rm --stop --force db-pitr >/dev/null 2>&1
docker volume rm --force donhang_db-pitr-data >/dev/null
RECOVERY_TARGET_TIME="$target" docker compose --profile pitr up --detach db-pitr 2>/dev/null
for _ in $(seq 120); do
  state=$(on_pitr --tuples-only --no-align --command "SELECT pg_get_wal_replay_pause_state()" 2>/dev/null || true)
  [ "$state" = "paused" ] && break
  sleep 1
done
if [ "$state" != "paused" ]; then
  echo "db-pitr did not reach recovery_target_time:" >&2
  docker compose --profile pitr logs --tail 20 db-pitr >&2
  exit 1
fi
echo "db-pitr stopped replaying the WAL at recovery_target_time: $state"

echo "== order 3's items, on db then on db-pitr"
on_db --command "$items_of_order_3"
on_pitr --command "$items_of_order_3"

echo "== copy them from db-pitr back into db"
on_pitr --tuples-only --no-align --command "COPY ($items_of_order_3) TO STDOUT" \
  | on_db --command "COPY order_items FROM STDIN"
on_db --command "$items_of_order_3"

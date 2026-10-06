#!/usr/bin/env bash
# Count donhang_perf's orders per shard with 4 shards, sharded by customer_id and by order id.
set -euo pipefail
# donhang_perf is built from the host (perf-db.sh drives docker compose); the
# queries then run inside the lab box.
if [ ! -f /.dockerenv ]; then
  built=$("$(dirname "$0")/perf-db.sh" --if-missing 2>&1) || { echo "$built" >&2; exit 1; }
  exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"
fi

echo "== customer_id % 4, then id % 4"
psql --host db --username donhang --dbname donhang_perf \
     --no-psqlrc --set ON_ERROR_STOP=on --pset footer=off \
     --file /repo/db/sharding/shard-skew.sql

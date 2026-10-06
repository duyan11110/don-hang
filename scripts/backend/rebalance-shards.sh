#!/usr/bin/env bash
# Count the orders of donhang_perf that change shard when a fifth shard is added: with id % N, then with a 64-bucket shard map.
set -euo pipefail
# donhang_perf is built from the host (perf-db.sh drives docker compose); the
# queries then run inside the lab box.
if [ ! -f /.dockerenv ]; then
  built=$("$(dirname "$0")/perf-db.sh" --if-missing 2>&1) || { echo "$built" >&2; exit 1; }
  exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"
fi

psql --host db --username donhang --dbname donhang_perf \
     --no-psqlrc --set ON_ERROR_STOP=on --pset footer=off --echo-queries \
     --file /repo/db/sharding/rebalance.sql

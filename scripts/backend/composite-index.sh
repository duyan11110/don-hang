#!/usr/bin/env bash
# Compare the plan for one customer's next page of orders with the (customer_id, id) index and without it.
set -euo pipefail
# donhang_perf is built on the host (it needs dotnet); the queries then run
# inside the lab box.
if [ ! -f /.dockerenv ]; then
  "$(dirname "$0")/perf-db.sh" --if-missing
  exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"
fi

# Unaligned: each plan line prints as it is, without a padded table around it.
psql --host db --username donhang --dbname donhang_perf \
     --no-psqlrc --echo-queries --set ON_ERROR_STOP=on \
     --pset format=unaligned --pset footer=off \
     --file /repo/db/queries/composite-index.sql

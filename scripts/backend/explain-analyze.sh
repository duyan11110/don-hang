#!/usr/bin/env bash
# Read PostgreSQL's plans for queries on donhang_perf: estimates with EXPLAIN, real timings with EXPLAIN ANALYZE.
set -euo pipefail
# donhang_perf is built on the host (it needs dotnet); the queries then run
# inside the lab box.
if [ ! -f /.dockerenv ]; then
  # Quietly: what perf-db.sh prints while it builds is not this script's
  # output; it is shown only if the build fails.
  built=$("$(dirname "$0")/perf-db.sh" --if-missing 2>&1) || { echo "$built" >&2; exit 1; }
  exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"
fi

# Unaligned: each plan line prints as it is, without a padded table around it.
psql --host db --username donhang --dbname donhang_perf \
     --no-psqlrc --echo-queries --set ON_ERROR_STOP=on \
     --pset format=unaligned --pset footer=off \
     --file /repo/db/queries/explain-analyze.sql

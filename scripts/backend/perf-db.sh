#!/usr/bin/env bash
# Build donhang_perf: the EF Core migrations applied to an empty database, then 200,000 orders.
# Runs on the host: it needs docker (for the db container and the migration bundle).
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1

psql_in_db() {
  docker compose exec -T db psql --username donhang --no-psqlrc --quiet --set ON_ERROR_STOP=on "$@"
}

# --if-missing: leave an existing donhang_perf alone (the plan scripts call it this way).
if [ "${1:-}" = "--if-missing" ] &&
   [ "$(psql_in_db --dbname postgres --tuples-only --no-align \
          --command "SELECT count(*) FROM pg_database WHERE datname = 'donhang_perf'")" = "1" ]; then
  exit 0
fi

psql_in_db --dbname postgres --command "DROP DATABASE IF EXISTS donhang_perf" \
                             --command "CREATE DATABASE donhang_perf"

# The schema comes from the same migration bundle as the api's database (the
# migrate service), pointed at donhang_perf instead; not from db/schema.sql.
password=$(grep '^POSTGRES_PASSWORD=' .env | cut -d= -f2-)
docker compose run --rm --no-deps migrate \
  --connection "Host=db;Database=donhang_perf;Username=donhang;Password=$password" >/dev/null

psql_in_db --dbname donhang_perf --file - < db/perf/fill.sql >/dev/null

psql_in_db --dbname donhang_perf --tuples-only --no-align --field-separator ': ' \
  --command "SELECT 'migrations applied', count(*) FROM \"__EFMigrationsHistory\"" \
  --command "SELECT 'customers', count(*) FROM customers" \
  --command "SELECT 'orders', count(*) FROM orders"

#!/usr/bin/env bash
# Copy donhang_perf's orders into two shards by customer_id % 2, then query them with the sharded-orders sample.
# Runs on the host: it drives the db container with docker compose and runs the sample with dotnet.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1

built=$(scripts/backend/perf-db.sh --if-missing 2>&1) || { echo "$built" >&2; exit 1; }

psql_in_db() {
  docker compose exec -T db psql --username donhang --no-psqlrc --quiet --set ON_ERROR_STOP=on "$@"
}

# lesson: backend.l3.cross-shard-queries
# Two shards, each its own database with the same orders table. Real shards
# sit on separate servers; in the lab both live on db. One database cannot
# read another's tables, so the rows travel out of donhang_perf with COPY
# and into the shard the same way.
for shard in 0 1; do
  psql_in_db --dbname postgres --command "SET client_min_messages TO warning" \
             --command "DROP DATABASE IF EXISTS donhang_shard_$shard WITH (FORCE)" \
             --command "CREATE DATABASE donhang_shard_$shard"
  psql_in_db --dbname "donhang_shard_$shard" --file - < db/sharding/shard-schema.sql
  psql_in_db --dbname donhang_perf --command \
      "COPY (SELECT id, customer_id, placed_at, status FROM orders WHERE customer_id % 2 = $shard) TO STDOUT" \
    | psql_in_db --dbname "donhang_shard_$shard" --command "COPY orders FROM STDIN"
  psql_in_db --dbname "donhang_shard_$shard" --tuples-only --no-align \
             --command "ANALYZE orders" \
             --command "SELECT 'donhang_shard_$shard: ' || count(*) || ' orders' FROM orders"
done
echo

# The sample connects from this machine, to the port db publishes.
PGPASSWORD=$(grep '^POSTGRES_PASSWORD=' .env | cut -d= -f2-)
export PGPASSWORD
dotnet run --project samples/DonHang.Samples --verbosity quiet -- sharded-orders

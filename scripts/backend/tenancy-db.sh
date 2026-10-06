#!/usr/bin/env bash
# Build the multi-tenancy lab databases: donhang_tenancy (shared tables, a schema per shop), donhang_shop_1 and donhang_shop_2.
# Runs on the host: it drives the db container with docker compose.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1

psql_in_db() {
  docker compose exec -T db psql --username donhang --no-psqlrc --quiet --set ON_ERROR_STOP=on "$@"
}

# --if-missing: leave an existing donhang_tenancy alone (the lesson scripts call it this way).
if [ "${1:-}" = "--if-missing" ] &&
   [ "$(psql_in_db --dbname postgres --tuples-only --no-align \
          --command "SELECT count(*) FROM pg_database WHERE datname = 'donhang_tenancy'")" = "1" ]; then
  exit 0
fi

for db in donhang_tenancy donhang_shop_1 donhang_shop_2; do
  psql_in_db --dbname postgres --command "SET client_min_messages TO warning"                                --command "DROP DATABASE IF EXISTS $db WITH (FORCE)" \
                               --command "CREATE DATABASE $db"
done

psql_in_db --dbname donhang_tenancy --file - < db/tenancy/shared-schema.sql
psql_in_db --dbname donhang_tenancy --file - < db/tenancy/schema-per-shop.sql
psql_in_db --dbname donhang_shop_1 --set shop=1 --file - < db/tenancy/database-per-shop.sql
psql_in_db --dbname donhang_shop_2 --set shop=2 --file - < db/tenancy/database-per-shop.sql

psql_in_db --dbname donhang_tenancy --tuples-only --no-align --field-separator ': ' \
  --command "SELECT 'donhang_tenancy, shared orders', count(*) FROM public.orders" \
  --command "SELECT 'donhang_tenancy, schema shop_1', count(*) FROM shop_1.orders" \
  --command "SELECT 'donhang_tenancy, schema shop_2', count(*) FROM shop_2.orders"
for shop in 1 2; do
  psql_in_db --dbname "donhang_shop_$shop" --tuples-only --no-align --field-separator ': ' \
    --command "SELECT 'donhang_shop_$shop', count(*) FROM orders"
done

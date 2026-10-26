#!/usr/bin/env bash
# Dump the old notifications and payments tables of a stage-3 donhang into the backups volume, then apply DropOldNotificationsTable: the dump keeps the rows, notifications is gone, payments stays.
# Runs on the host: it needs docker (for the db container, the lab box and the migration bundle).
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1

# The lab's own donhang applied DropOldNotificationsTable when it started, so
# this works on donhang_release: a copy of donhang built the way db builds
# it (schema.sql, seed.sql, the migration baseline), then migrated only up
# to the last migration of stage-3, as production stood before this release.
psql_in_db() {
  docker compose exec -T db psql --username donhang --no-psqlrc --quiet --set ON_ERROR_STOP=on "$@"
}
release_db() { psql_in_db --dbname donhang_release "$@"; }
password=$(grep '^POSTGRES_PASSWORD=' .env | cut -d= -f2-)
migrate_to() {
  docker compose run --rm --no-deps migrate "$@" \
    --connection "Host=db;Database=donhang_release;Username=donhang;Password=$password" \
    | grep -o "Applying migration '[^']*'" | sed 's/^/  /' || true
}
tables() {
  release_db --tuples-only --no-align --command \
    "SELECT name || ': ' || CASE WHEN to_regclass(name) IS NULL THEN 'no such table' ELSE 'a table' END
       FROM unnest(ARRAY['notifications', 'payments']) AS name" | sed 's/^/  /'
}

psql_in_db --dbname postgres --command "SET client_min_messages = warning" \
                             --command "DROP DATABASE IF EXISTS donhang_release" \
                             --command "CREATE DATABASE donhang_release"
trap 'psql_in_db --dbname postgres --command "DROP DATABASE IF EXISTS donhang_release"' EXIT
cat db/schema.sql db/seed.sql db/migrations-baseline.sql | release_db --file - >/dev/null
echo "== donhang_release, migrated to the last migration of stage-3"
migrate_to 20261006004259_AddOutboxTraceParent >/dev/null
tables
release_db --tuples-only --no-align --field-separator ': ' \
  --command "SELECT 'rows in notifications', count(*) FROM notifications" \
  --command "SELECT 'rows in payments', count(*) FROM payments" | sed 's/^/  /'

# lesson: backend.l4.expand-and-contract
# Step 1 of ADR 0008: both old tables go into one custom-format dump, next
# to the other backups, before any migration drops one of them.
dump=/backups/old-tables/donhang-old-tables.dump
echo "== pg_dump -Fc --table notifications --table payments -> $dump"
docker compose exec -T lab bash -c "mkdir -p /backups/old-tables &&
  pg_dump --host db --username donhang --dbname donhang_release --format custom \
          --table notifications --table payments --file $dump &&
  pg_restore --list $dump | grep -E 'TABLE DATA' | sed 's/^[0-9]*; [0-9 ]*/  /'"

echo "== the release's migrations"
migrate_to
echo "== afterwards"
tables
echo "== the rows of the dropped table are still in the dump"
docker compose exec -T lab bash -c "pg_restore --data-only --table notifications --file - $dump |
  awk '/^COPY /{inside=1; next} /^\\\\.\$/{inside=0} inside{rows++} END{print \"  notifications rows in the dump: \" rows+0}'"

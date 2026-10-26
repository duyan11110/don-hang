#!/usr/bin/env bash
# Promote db-replica with pg_promote() while db still runs, then give product 1 a different price on each: two primaries that disagree, a split brain.
set -euo pipefail
# db-replica is started from the host (docker compose, profile replica), as a
# fresh copy of db, and removed with its volume at the end; the queries run
# inside the lab box.
if [ ! -f /.dockerenv ]; then
  cd "$(dirname "$0")/../.."
  remove_replica() {
    docker compose --profile replica rm --stop --force db-replica >/dev/null 2>&1
    docker volume rm --force donhang_db-replica-data >/dev/null
  }
  remove_replica
  started=$(docker compose --profile replica up --detach --wait db-replica 2>&1) || { echo "$started" >&2; exit 1; }
  trap remove_replica EXIT
  scripts/lab-run.sh "$0" "$@"
  echo "(db-replica and its volume are removed now)"
  exit 0
fi

on() {
  local server=$1
  shift
  echo "-- on $server"
  psql --host "$server" --username donhang --dbname donhang --no-psqlrc \
       --echo-queries --pset footer=off "$@"
}

price=$(psql --host db --username donhang --dbname donhang --no-psqlrc --tuples-only --no-align \
             --command "SELECT price_vnd FROM products WHERE id = 1")
trap 'psql --host db --username donhang --dbname donhang --no-psqlrc --quiet \
           --command "UPDATE products SET price_vnd = $price WHERE id = 1"' EXIT

echo "== db-replica follows db"
on db-replica --command "SELECT pg_is_in_recovery() AS replica"

# lesson: k8s.l4.data-decides-failover
# pg_promote() ends recovery: db-replica stops following db and accepts
# writes. Nothing stopped db first, so both now take writes, and nothing
# carries a change from one to the other: two primaries, a split brain.
echo "== promote db-replica while db still runs"
on db-replica --command "SELECT pg_promote() AS promoted"
on db-replica --command "SELECT pg_is_in_recovery() AS replica"

echo "== each primary accepts its own price for product 1"
on db --command "UPDATE products SET price_vnd = 1300000 WHERE id = 1"
on db-replica --command "UPDATE products SET price_vnd = 1200000 WHERE id = 1"
echo "== and each answers with its own"
on db --command "SELECT price_vnd FROM products WHERE id = 1"
on db-replica --command "SELECT price_vnd FROM products WHERE id = 1"
echo "(product 1 gets its old price back on db when this script ends)"

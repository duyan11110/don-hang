#!/usr/bin/env bash
# Start db-replica, send it an UPDATE, then change a price on db and read it at once on both servers.
set -euo pipefail
# db-replica is started from the host (docker compose, profile replica), as a
# fresh copy of db on every run; the queries then run inside the lab box.
if [ ! -f /.dockerenv ]; then
  cd "$(dirname "$0")/../.."
  docker compose --profile replica rm --stop --force db-replica >/dev/null 2>&1
  docker volume rm --force donhang_db-replica-data >/dev/null
  started=$(docker compose --profile replica up --detach --wait db-replica 2>&1) || { echo "$started" >&2; exit 1; }
  exec scripts/lab-run.sh "$0" "$@"
fi

on() {
  local server=$1
  shift
  echo "-- on $server"
  psql --host "$server" --username donhang --dbname donhang --no-psqlrc \
       --echo-queries --pset footer=off "$@"
}

echo "== db-replica answers queries"
on db-replica --command "SELECT pg_is_in_recovery() AS replica, count(*) AS products FROM products"
echo "== but refuses writes"
on db-replica --command "UPDATE products SET price_vnd = 1300000 WHERE id = 1" || true
echo

price=$(psql --host db --username donhang --dbname donhang --no-psqlrc --tuples-only --no-align \
             --command "SELECT price_vnd FROM products WHERE id = 1")
trap 'psql --host db --username donhang --dbname donhang --no-psqlrc --quiet \
           --command "UPDATE products SET price_vnd = $price WHERE id = 1"' EXIT

# lesson: backend.l3.read-replicas
# The UPDATE has committed on db when psql returns; the replica receives it
# right away but, in this lab, waits 5 s before applying it.
echo "== a new price for product 1 on db, then the same read on both servers"
on db --command "UPDATE products SET price_vnd = 1300000 WHERE id = 1"
on db --command "SELECT price_vnd FROM products WHERE id = 1"
on db-replica --command "SELECT price_vnd FROM products WHERE id = 1"
sleep 6
echo "== 6 seconds later, on db-replica"
on db-replica --command "SELECT price_vnd FROM products WHERE id = 1"
echo "(product 1 gets its old price back on db when this script ends)"

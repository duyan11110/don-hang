#!/usr/bin/env bash
# Stop PostgreSQL while Redis holds product 3: reading product 3 is still answered, listing products and placing an order fail.
# Runs on the host: it stops and starts db with docker compose.
set -euo pipefail
cd "$(dirname "$0")/../.."

source scripts/lib/keycloak.sh
# Signed in before db stops: Keycloak keeps its data in the same server.
token=$(keycloak_access_token anh.tran@example.com)

status() { curl -sS -o /dev/null -w '%{http_code}' "$@"; }

# Afterwards db comes back and every service that uses it (the api,
# Notifications, Payments, Keycloak) answers again before the script ends.
restore() {
  docker compose start db >/dev/null 2>&1
  docker compose up --wait db >/dev/null 2>&1
  # Keycloak's connection pool keeps the connections db closed and hands them
  # out again ("This connection has been closed"), so sign-ins fail until it
  # restarts; the .NET services drop theirs on the first error.
  docker compose restart keycloak >/dev/null 2>&1
  docker compose up --wait api notifications payments keycloak >/dev/null 2>&1
  for _ in $(seq 60); do
    [ "$(status http://localhost:8080/api/v1/products)" = 200 ] && break
    sleep 1
  done
}

echo "== db is up: read product 3, which puts a copy of it in Redis"
echo "  GET /api/v1/products/3 -> $(status http://localhost:8080/api/v1/products/3)"
echo "  copy in Redis: $(docker compose exec -T redis redis-cli EXISTS product:3 | sed 's/^1$/yes/;s/^0$/no/')"

# lesson: backend.l4.cap-theorem
# Stopping the container stands in for a partition between the api and its
# database: the api still runs and still reaches Redis, but not PostgreSQL.
# (A real partition can also make calls hang; a stopped server fails fast.)
docker compose stop db >/dev/null 2>&1
trap restore EXIT
echo "== db is stopped"
echo "  GET /api/v1/products/3 (the copy in Redis) -> $(status http://localhost:8080/api/v1/products/3)"
echo "  GET /api/v1/products (no copy, needs db) -> $(status http://localhost:8080/api/v1/products)"
echo "  POST /api/v1/orders (must be saved in db) -> $(status -X POST http://localhost:8080/api/v1/orders \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $token" \
  -d '{"items":[{"productId":3,"quantity":1}]}')"

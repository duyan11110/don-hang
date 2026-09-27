#!/usr/bin/env bash
# Ask the api for one page of orders, then read the SQL EF Core logged for it in the api's log.
# Runs on the host: it reads the api container's log with docker compose.
set -euo pipefail
cd "$(dirname "$0")/../.."

base=http://localhost:8080/api/v1
token=$(curl -sS -X POST "$base/auth/login" \
  -H 'Content-Type: application/json' \
  -d '{"email":"dung.le@example.com","password":"donhang-dev-password"}' \
  | sed -E 's/.*"token":"([^"]+)".*/\1/')

echo "GET /api/v1/orders?after=5&limit=20 as customer 3:"
curl -sS "$base/orders?after=5&limit=20" -H "Authorization: Bearer $token"
echo
echo

# lesson: backend.l2.efcore-generated-sql
# Each command EF Core sends is one log entry under this category: how long
# it took, its parameters (their values hidden as '?'), then the SQL itself.
echo "what EF Core logged for it:"
sleep 1 # let the api's logger write the entry out first
docker compose logs --no-log-prefix --tail 60 api | awk '
  /^info: Microsoft.EntityFrameworkCore.Database.Command/ { entry = $0; inside = 1; next }
  inside && /^      / { entry = entry "\n" $0; next }
  inside { inside = 0; if (entry ~ /FROM orders/) last = entry }
  END { print last }'

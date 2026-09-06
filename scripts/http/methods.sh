#!/usr/bin/env bash
# The same address, five verbs, five different answers.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

base=http://localhost:8080/api/v1/orders

curl -sS -o /dev/null -w 'GET    /api/v1/orders/1  -> %{http_code}\n' "$base/1"
curl -sS -o /dev/null -w 'POST   /api/v1/orders    -> %{http_code}\n' \
     -H 'Content-Type: application/json' -d '{"customer_id":1}' "$base"
curl -sS -o /dev/null -w 'PUT    /api/v1/orders/1  -> %{http_code}\n' -X PUT "$base/1"
curl -sS -o /dev/null -w 'PATCH  /api/v1/orders/1  -> %{http_code}\n' -X PATCH "$base/1"
curl -sS -o /dev/null -w 'DELETE /api/v1/orders/1  -> %{http_code}\n' -X DELETE "$base/1"

echo
echo "POST creates, so it also says where the new thing lives:"
curl -sS -D - -o /dev/null -X POST \
     -H 'Content-Type: application/json' -d '{"customer_id":1}' "$base" \
  | grep -Ei '^(HTTP/|Location:)'

echo
echo "GET changes nothing, so asking twice gives the same thing twice:"
curl -sS "$base/1"; echo
curl -sS "$base/1"; echo

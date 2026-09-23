#!/usr/bin/env bash
# Sign in, list products, place an order, and read it back — the same three
# calls DonHang.App makes (lib/api_client.dart), from the terminal instead.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

base=http://localhost:8080/api/v1

echo "products (no sign-in needed):"
curl -sS "$base/products" | head -c 200
echo
echo

echo "sign in as customer 1:"
token=$(curl -sS -X POST "$base/auth/login" \
  -H 'Content-Type: application/json' \
  -d '{"email":"anh.tran@example.com","password":"donhang-dev-password"}' \
  | sed -E 's/.*"token":"([^"]+)".*/\1/')
echo "  got a token: ${token:0:20}..."
echo

echo "place an order with that token:"
order=$(curl -sS -X POST "$base/orders" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $token" \
  -d '{"items":[{"productId":2,"quantity":1,"unitPriceVnd":450000}]}')
echo "$order"
order_id=$(echo "$order" | sed -E 's/.*"id":([0-9]+).*/\1/')
echo

echo "read the order back:"
curl -sS "$base/orders/$order_id"
echo

echo "the same request without a token:"
curl -sS -o /dev/null -w '%{http_code}\n' -X POST "$base/orders" \
  -H 'Content-Type: application/json' \
  -d '{"items":[{"productId":2,"quantity":1,"unitPriceVnd":450000}]}'

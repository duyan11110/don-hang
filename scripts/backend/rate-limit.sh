#!/usr/bin/env bash
# Place orders as one customer until the api answers 429 with Retry-After, then place one as another customer.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

source "$(dirname "$0")/../lib/keycloak.sh"
# Prints the status code and, when there is one, the Retry-After header.
place_order() {
  curl -sS -o /dev/null -D - -X POST http://localhost:8080/api/v1/orders \
    -H 'Content-Type: application/json' -H "Authorization: Bearer $1" \
    -d '{"items":[{"productId":8,"quantity":1}]}' \
    | tr -d '\r' | awk 'NR == 1 { code = $2 } tolower($1) == "retry-after:" { after = $2 }
                        END { print code (after ? " Retry-After: " after : "") }'
}

# lesson: backend.l3.rate-limiting
# In the lab each customer may place 10 orders per window of 10 s
# (RateLimiting__Orders__Window in docker-compose.yml). The 11th within one
# window is refused before OrdersController runs: 429, and Retry-After says
# in how many seconds the window ends. Khánh is a customer no other script
# places orders as, so his window starts with his first order here.
khanh=$(keycloak_access_token khanh.vu@example.com)
echo "== POST /api/v1/orders as customer 5, until the api refuses one"
accepted=0
for _ in $(seq 15); do
  answer=$(place_order "$khanh")
  [ "${answer%% *}" = 201 ] || break
  accepted=$((accepted + 1))
done
echo "  201 Created, $accepted times"
echo "  then: $answer"

# The count is per customer: another customer's order goes through.
chau=$(keycloak_access_token chau.nguyen@example.com)
echo "== POST /api/v1/orders as customer 2, at the same moment"
echo "  $(place_order "$chau")"

# Wait out the window, so that the scripts after this one find it reset.
retry_after=${answer##* }
sleep "$retry_after"
echo "== POST /api/v1/orders as customer 5, Retry-After seconds later"
echo "  $(place_order "$khanh")"

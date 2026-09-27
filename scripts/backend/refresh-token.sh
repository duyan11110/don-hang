#!/usr/bin/env bash
# Log in, renew the access token with the refresh token, log out, and see which token still works where.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

base=http://localhost:8080/api/v1
source "$(dirname "$0")/../lib/keycloak.sh"
call_api() {
  curl -sS -o /dev/null -w '  -> %{http_code}\n' "$base/orders/1" -H "Authorization: Bearer $1"
}

echo "== log in as customer 1"
tokens=$(keycloak_sign_in anh.tran@example.com)
access_token=$(jq -r .access_token <<<"$tokens")
refresh_token=$(jq -r .refresh_token <<<"$tokens")
jq '{expires_in, refresh_expires_in}' <<<"$tokens"
echo "access token: exp - iat = $(jwt_claims "$access_token" | jq '.exp - .iat') seconds"
echo

echo "== GET /api/v1/orders/1 with the access token, then with the refresh token"
call_api "$access_token"
call_api "$refresh_token"
echo

# lesson: backend.l2.refresh-tokens
# The app, not the customer, asks for a new access token: the refresh token
# goes to Keycloak's token endpoint, never to the api.
echo "== renew: grant_type=refresh_token"
renewed=$(curl -sS "$keycloak/token" \
  -d grant_type=refresh_token -d client_id=donhang-app -d "refresh_token=$refresh_token")
new_access_token=$(jq -r .access_token <<<"$renewed")
if [ "$new_access_token" != "$access_token" ]; then different=yes; else different=no; fi
echo "a new access token, different from the first: $different"
call_api "$new_access_token"
echo

# lesson: backend.l2.refresh-tokens
# Logging out ends the session at Keycloak, and every refresh token of it.
echo "== log out at Keycloak"
curl -sS -o /dev/null -w '  -> %{http_code}\n' "$keycloak/logout" \
  -d client_id=donhang-app -d "refresh_token=$(jq -r .refresh_token <<<"$renewed")"
echo "== renew again after logging out"
curl -sS "$keycloak/token" \
  -d grant_type=refresh_token -d client_id=donhang-app -d "refresh_token=$refresh_token"
echo
echo "== the access token from before the logout, at the api (it has not reached its exp)"
call_api "$new_access_token"

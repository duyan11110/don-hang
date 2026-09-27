#!/usr/bin/env bash
# Log in with and without the openid scope, read the ID token and the access token, then send each to the api.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

base=http://localhost:8080/api/v1
source "$(dirname "$0")/../lib/keycloak.sh"

echo "== fields of Keycloak's token response, scope \"profile email\" (plain OAuth 2.0):"
keycloak_sign_in anh.tran@example.com "profile email" | jq -c 'keys'
echo "== the same, scope \"openid profile email\" (OpenID Connect):"
tokens=$(keycloak_sign_in anh.tran@example.com "openid profile email")
jq -c 'keys' <<<"$tokens"
echo

# lesson: backend.l2.openid-connect-id-token
# The ID token is addressed to the app (aud = its client_id) and says who
# logged in; the access token is addressed to the api (aud = donhang-api).
id_token=$(jq -r .id_token <<<"$tokens")
access_token=$(jq -r .access_token <<<"$tokens")
echo "== ID token, the claims the app reads:"
jwt_claims "$id_token" | jq '{iss, aud, sub, typ, name, email}'
echo "== access token, the claims the api reads:"
jwt_claims "$access_token" | jq '{iss, aud, sub, typ, azp, roles}'
echo

echo "== GET /api/v1/orders/1 with the ID token:"
curl -sS -o /dev/null -w '  -> %{http_code}\n' "$base/orders/1" -H "Authorization: Bearer $id_token"
echo "== GET /api/v1/orders/1 with the access token:"
curl -sS -o /dev/null -w '  -> %{http_code}\n' "$base/orders/1" -H "Authorization: Bearer $access_token"

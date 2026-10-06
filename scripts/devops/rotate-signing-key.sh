#!/usr/bin/env bash
# Give Keycloak's donhang realm a new signing key with a higher priority, and send the api a token signed with the old key and one with the new.
# Runs on the host: it drives Keycloak's admin CLI inside the keycloak container with docker compose.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1
source scripts/lib/keycloak.sh

# kcadm.sh is Keycloak's admin command line. It signs in inside the keycloak
# container, as the bootstrap admin whose password that container already has.
kcadm() { docker compose exec -T keycloak /opt/keycloak/bin/kcadm.sh "$@" --config /tmp/kcadm.config; }
docker compose exec -T keycloak bash -c '/opt/keycloak/bin/kcadm.sh config credentials --config /tmp/kcadm.config \
  --server http://localhost:8080 --realm master \
  --user "$KC_BOOTSTRAP_ADMIN_USERNAME" --password "$KC_BOOTSTRAP_ADMIN_PASSWORD"' >/dev/null 2>&1

# The key id ("kid") in a token's header: the first part of the JWT, base64url.
kid_of() {
  local header
  header=$(printf %s "$1" | cut -d. -f1 | tr '_-' '/+')
  while [ $(( ${#header} % 4 )) -ne 0 ]; do header="$header="; done
  printf %s "$header" | base64 -d | sed -nE 's/.*"kid" *: *"([^"]+)".*/\1/p'
}
active_kid() { kcadm get keys -r donhang 2>/dev/null | sed -nE 's/.*"RS256" : "([^"]+)".*/\1/p'; }
api_status() {
  curl -sS -w '
%{http_code}' http://localhost:8080/api/v1/orders -H "Authorization: Bearer $1" | tail -n 1
}
lifespan=$(kcadm get realms/donhang --fields accessTokenLifespan --format csv --noquotes)

# Housekeeping, not part of the lesson: an earlier run left the keys it
# retired. Once the key that replaced them is older than an access token's
# lifespan, no token they signed is still valid, so they are removed.
providers=$(kcadm get components -r donhang -q providerId=rsa-generated --fields id,name --format csv --noquotes)
newest=$(printf '%s\n' "$providers" | sed -nE 's/^[^,]*,rotated-([0-9]+)$/\1/p' | sort -n | tail -n 1)
if [ -n "$newest" ] && [ $(( $(date +%s) - newest )) -gt "$lifespan" ]; then
  for id in $(printf '%s\n' "$providers" | grep -v ",rotated-$newest$" | cut -d, -f1); do
    kcadm delete "components/$id" -r donhang
  done
fi

old_token=$(keycloak_access_token anh.tran@example.com)
echo "== before: a token from the active key"
echo "  token's kid is the active RS256 key: $([ "$(kid_of "$old_token")" = "$(active_kid)" ] && echo yes || echo no)"
echo "  GET /api/v1/orders with it -> $(api_status "$old_token")"

# lesson: devops.l3.secret-rotation
# A second RS256 key, with a priority above every key the realm has: from
# now on Keycloak signs new tokens with it. The old key stays in the realm,
# no longer signing, so tokens it already signed still check out.
priority=$(kcadm get components -r donhang -q providerId=rsa-generated --fields 'config(priority)' --format csv --noquotes \
  | tr -d '[]"' | sort -n | tail -n 1)
realm_id=$(kcadm get realms/donhang --fields id --format csv --noquotes)
kcadm create components -r donhang -s name="rotated-$(date +%s)" -s providerId=rsa-generated \
  -s providerType=org.keycloak.keys.KeyProvider -s parentId="$realm_id" \
  -s "config.priority=[\"$(( priority + 10 ))\"]" -s 'config.algorithm=["RS256"]' >/dev/null 2>&1
echo "== after adding a key with priority $(( priority + 10 ))"

new_token=$(keycloak_access_token anh.tran@example.com)
echo "  a new token's kid is the new key's: $([ "$(kid_of "$new_token")" = "$(active_kid)" ] && echo yes || echo no)"
echo "  and differs from the old token's: $([ "$(kid_of "$new_token")" != "$(kid_of "$old_token")" ] && echo yes || echo no)"
# lesson: devops.l3.secret-rotation
# The api has never seen the new kid. It fetches Keycloak's keys again by
# itself, without a restart, but in the background and at most once every
# 5 minutes (JwtBearer's RefreshInterval): until then it answers 401 to
# tokens from the new key. Ask again every 5 s, for up to 6 minutes.
waited=0
until [ "$(api_status "$new_token")" = "200" ] || [ "$waited" -ge 360 ]; do
  sleep 5
  waited=$(( waited + 5 ))
done
echo "  GET /api/v1/orders with the new token -> $(api_status "$new_token") (after $waited s)"
echo "  GET /api/v1/orders with the old token -> $(api_status "$old_token")"
echo "the old key can go once every token it signed has expired: ${lifespan} s after this rotation"

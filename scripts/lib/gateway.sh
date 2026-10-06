# Plumbing, not a lesson: sourced by the scripts of scripts/k8s/ that call
# staging from this machine through its Gateway over HTTPS, once
# scripts/k8s/gateway-tls.sh has run. The caller has already done `cd` to
# the repository's root.
source scripts/lib/keycloak.sh

gateway=https://donhang.localhost:18443
# Sign in with Keycloak through the Gateway too (keycloak_access_token).
keycloak=https://auth.donhang.localhost:18443/realms/donhang/protocol/openid-connect
# curl trusts the lab's own certificate authority (scripts/dev-secrets.sh).
export CURL_CA_BUNDLE=secrets/lab-ca.crt

# gateway_token <email>: an access token, waiting for Keycloak if it is
# still starting.
gateway_token() {
  local token
  for _ in $(seq 60); do
    token=$(keycloak_access_token "$1" 2>/dev/null) && [ -n "$token" ] && { echo "$token"; return 0; }
    sleep 2
  done
  echo "no token for $1 from $keycloak" >&2
  return 1
}

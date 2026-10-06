# Plumbing, not a lesson: sourced by the scripts of scripts/k8s/ that call
# staging from this machine through its Gateway over HTTPS, once
# scripts/k8s/gateway-tls.sh has run. The caller has already done `cd` to
# the repository's root.
source scripts/lib/keycloak.sh

gateway=https://donhang.localhost:18443
# Sign in with Keycloak through the Gateway too (keycloak_access_token).
keycloak=https://auth.donhang.localhost:18443/realms/donhang/protocol/openid-connect

# Every curl here trusts the lab's own certificate authority
# (scripts/dev-secrets.sh). curl on Windows checks certificates through
# Schannel, which also asks for revocation data that this CA does not
# publish: that check is skipped there (other builds of curl do not make it).
curl_tls=(--cacert secrets/lab-ca.crt)
if command curl --version | grep -q Schannel; then
  curl_tls+=(--ssl-no-revoke)
fi
curl() { command curl "${curl_tls[@]}" "$@"; }

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

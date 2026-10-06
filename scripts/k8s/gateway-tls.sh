#!/usr/bin/env bash
# Turn on HTTPS at staging's Gateway: seal the lab certificate as donhang-tls, commit the https listener, the redirect and Keycloak's HTTPS address, then call the api and Keycloak from outside the cluster.
# Runs on the host, like every script in scripts/k8s/: kubectl, git and curl talk to donhang-staging and its Git server from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/gitops.sh
source scripts/lib/keycloak.sh
show() { echo "\$ $*"; "$@"; }
# curl on Windows checks certificates through Schannel, which also asks
# for revocation data that the lab's own CA does not publish: skip that
# check there (other builds of curl do not make it).
if command curl --version | grep -q Schannel; then
  curl() { command curl --ssl-no-revoke "$@"; }
fi
[ -d "$config_repo/platform/edge" ] || scripts/k8s/gateway.sh >/dev/null
api=https://donhang.localhost:18443/api/v1/products

# The Secret donhang-tls, sealed: the certificate dev-secrets.sh signed with
# the lab's own certificate authority, for donhang.localhost and
# auth.donhang.localhost.
echo "== the certificate in secrets/donhang-tls.crt"
openssl x509 -in secrets/donhang-tls.crt -noout -subject -issuer -ext subjectAltName | sed '/^$/d'
scripts/devops/seal-secrets.sh --no-commit | grep donhang-tls
echo

# lesson: k8s.l2.tls-at-the-gateway
# One commit: the Gateway with its https listener and the redirect on the
# http listener, the routes moved to the https listener, and Keycloak's
# public address in HTTPS. Keycloak writes that address into every token as
# the issuer, so the api's Keycloak__Authority changes with it.
cp deploy/gitops/config-repo/platform/edge/gateway.yaml "$config_repo/platform/edge/"
routes_without_refunds deploy/gitops/config-repo/platform/edge/httproutes.yaml > "$config_repo/platform/edge/httproutes.yaml"
perl -pi -e 's#http://localhost:8180#https://auth.donhang.localhost:18443#' \
  "$config_repo/envs/staging/keycloak.yaml" "$config_repo/envs/staging/api-configmap.yaml"
git -C "$config_repo" diff -U0 -- envs/staging/keycloak.yaml envs/staging/api-configmap.yaml | grep '^[-+] ' || true
[ -z "$(git -C "$config_repo" status --porcelain)" ] || config_commit gateway-tls.sh "HTTPS at the Gateway; Keycloak's public address is https://auth.donhang.localhost:18443"
for app in edge-staging staging; do
  app_refresh
  app_wait_sync "$(config_head --verify)" >/dev/null
  app_wait Synced Healthy "$(config_head --verify)"
done
# The api reads its ConfigMap only when it starts: new Pods pick up the
# new Keycloak__Authority. (Keycloak's Deployment itself changed, so it
# rolled on its own.)
kubectl delete pods -n donhang -l app=api --wait=false >/dev/null
kubectl rollout status deployment/api -n donhang --timeout=300s >/dev/null
kubectl rollout status deployment/keycloak -n donhang --timeout=300s >/dev/null
echo

echo "== the Gateway's listeners"
kubectl get gateway donhang -n donhang \
  -o jsonpath='{range .status.listeners[*]}{.name}: {.attachedRoutes} route(s), {.conditions[?(@.type=="Programmed")].type}={.conditions[?(@.type=="Programmed")].status}{"\n"}{end}'
echo

# Plain HTTP now gets a redirect to the same path over HTTPS.
echo "== GET http://donhang.localhost:18080/api/v1/products"
for _ in $(seq 60); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' http://donhang.localhost:18080/api/v1/products)" = 301 ] && break
  sleep 1
done
curl -s -o /dev/null -w 'HTTP %{http_code}, Location: %{redirect_url}\n' http://donhang.localhost:18080/api/v1/products

# curl trusts the certificate only with the lab's CA certificate.
echo "== GET $api, without and with --cacert secrets/lab-ca.crt"
curl -sS -o /dev/null "$api" 2>&1 | grep '^curl: (' | sed -E 's/^curl: \(([0-9]+)\).*/curl: error \1, the certificate is not trusted/' || true
for _ in $(seq 60); do
  [ "$(curl -s --cacert secrets/lab-ca.crt -o /dev/null -w '%{http_code}' "$api")" = 200 ] && break
  sleep 1
done
curl -s --cacert secrets/lab-ca.crt -o /dev/null -w 'HTTP %{http_code} over HTTPS\n' "$api"
echo

# Signing in from outside the cluster: Keycloak through the Gateway, over
# HTTPS. The token's issuer is the HTTPS address, and the api accepts it.
# (scripts/lib/gateway.sh: curl trusts the lab CA from here on, and signs in
# through https://auth.donhang.localhost:18443.)
source scripts/lib/gateway.sh
token=$(gateway_token anh.tran@example.com)
payload=$(printf %s "$token" | cut -d. -f2 | tr '_-' '/+')
while [ $(( ${#payload} % 4 )) -ne 0 ]; do payload="$payload="; done
echo "== the token's issuer"
printf %s "$payload" | base64 -d | grep -o '"iss":"[^"]*"'
echo "== GET https://donhang.localhost:18443/api/v1/orders/1 (an order of anh.tran), without and with the token"
curl -s -o /dev/null -w 'HTTP %{http_code}\n' https://donhang.localhost:18443/api/v1/orders/1
curl -s -o /dev/null -w 'HTTP %{http_code}\n' -H "Authorization: Bearer $token" https://donhang.localhost:18443/api/v1/orders/1

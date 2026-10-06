#!/usr/bin/env bash
# Commit staging's Gateway and HTTPRoutes (platform/edge) to the config repository, apply the Application edge-staging that syncs them, and call the api and Keycloak through Traefik.
# Runs on the host, like every script in scripts/k8s/: kubectl, git and curl talk to donhang-staging and its Git server from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/gitops.sh
show() { echo "\$ $*"; "$@"; }
[ -d "$config_repo/.git" ] || scripts/devops/gitops-repo.sh >/dev/null

# lesson: k8s.l2.gateway-api
# The Gateway API objects go through the config repository like the rest of
# staging. HTTPS needs the certificate of k8s.l2.tls-at-the-gateway: until
# scripts/k8s/gateway-tls.sh, the Gateway is committed without its https
# listener and redirect (everything from the TLS lesson's first comment
# on), and the routes attach to the http listener. The route to Payments
# waits for scripts/k8s/stateful-staging.sh.
mkdir -p "$config_repo/platform/edge"
sed '/# lesson: k8s.l2.tls-at-the-gateway/,$d' deploy/gitops/config-repo/platform/edge/gateway.yaml \
  > "$config_repo/platform/edge/gateway.yaml"
routes_without_refunds deploy/gitops/config-repo/platform/edge/httproutes.yaml | sed 's/sectionName: https/sectionName: http/' \
  > "$config_repo/platform/edge/httproutes.yaml"
cp deploy/gitops/config-repo/apps/edge-staging.yaml "$config_repo/apps/edge-staging.yaml"
if [ -n "$(git -C "$config_repo" status --porcelain)" ]; then
  config_commit gateway.sh "Gateway API: the Gateway donhang and the HTTPRoutes api and keycloak"
fi
# Before this, no Application pointed at platform/edge.
show kubectl apply -f "$config_repo/apps/edge-staging.yaml"
app=edge-staging
app_refresh
app_wait_sync "$(config_head --verify)" >/dev/null
app_wait Synced Healthy "$(config_head --verify)"
echo

echo "== the Gateway and the routes attached to it"
kubectl wait --for=condition=Programmed gateway/donhang -n donhang --timeout=120s >/dev/null
kubectl get gateways,httproutes -n donhang
echo
echo "== the HTTPRoute api, as Traefik accepted it"
kubectl get httproute api -n donhang \
  -o jsonpath='{range .status.parents[*].conditions[*]}{.type}={.status} ({.reason}){"\n"}{end}'
echo

# The same paths as Caddy in Compose: /api/v1, /api/v2 and /openapi on
# donhang.localhost go to the api, the host auth.donhang.localhost to Keycloak.
# (/api/v2/orders/1 answers 401: the api wants a token for it.)
for url in http://donhang.localhost:18080/api/v1/products http://donhang.localhost:18080/api/v2/orders/1 \
           http://donhang.localhost:18080/openapi/v1.json \
           http://auth.donhang.localhost:18080/realms/donhang/.well-known/openid-configuration; do
  for _ in $(seq 30); do [ "$(curl -s -o /dev/null -w '%{http_code}' "$url")" != 404 ] && break; sleep 1; done
  echo "GET $url -> $(curl -s -o /dev/null -w '%{http_code}' "$url")"
done
# No route sends any other path anywhere: Traefik answers 404 itself.
echo "GET http://donhang.localhost:18080/index.html -> $(curl -s -o /dev/null -w '%{http_code}' http://donhang.localhost:18080/index.html)"

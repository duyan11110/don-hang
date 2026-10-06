#!/usr/bin/env bash
# Call Traefik from this machine before and after applying api-ingress.yaml: 404 until the rule exists, then the api's products; the Ingress is removed again at the end.
# Runs on the host, like every script in scripts/k8s/: curl calls Traefik through the port the staging node publishes, kubectl talks to donhang-staging.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }
kubectl() { command kubectl --context kind-donhang-staging "$@"; }
url=http://donhang.localhost:18080/api/v1/products
status() { curl -s -o /dev/null -w '%{http_code}' "$url"; }

kubectl delete -f deploy/k8s/lessons/api-ingress.yaml --ignore-not-found >/dev/null

# The api's Service has no type: only Pods inside the cluster can reach it.
show kubectl get service api -n donhang
echo

# lesson: k8s.l2.ingress
# Traefik's Pods already listen on port 18080 of this machine, but without
# a rule they have nowhere to send the request: 404, from Traefik itself.
echo "== GET $url, no Ingress yet"
echo "HTTP $(status)"
echo

# The Ingress names Traefik's class; Traefik watches Ingress objects, sees
# the new rule and forwards matching requests to the Service api.
show kubectl apply -f deploy/k8s/lessons/api-ingress.yaml
show kubectl get ingress api -n donhang
for _ in $(seq 60); do [ "$(status)" = 200 ] && break; sleep 1; done
echo
echo "== GET $url, with the Ingress"
curl -s -w '\nHTTP %{http_code}\n' "$url" | cut -c1-120
echo

# This Ingress only shows the idea: staging routes with Gateway API
# (scripts/k8s/gateway.sh), so the rule goes again.
show kubectl delete -f deploy/k8s/lessons/api-ingress.yaml

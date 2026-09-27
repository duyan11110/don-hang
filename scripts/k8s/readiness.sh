#!/usr/bin/env bash
# Roll out an api whose database host does not exist: its new Pod runs but never becomes ready, the update stalls, and the old Pods keep serving.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the kind cluster from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }

if ! kubectl get service api -n donhang >/dev/null 2>&1; then
  echo "The backend is not deployed: run scripts/k8s/deploy.sh first." >&2
  exit 1
fi
kubectl apply -f deploy/k8s/api.yaml >/dev/null
kubectl rollout status deployment/api -n donhang --timeout=300s >/dev/null

# lesson: k8s.l1.readiness-probes
show kubectl apply -f deploy/k8s/lessons/api-unready.yaml
# Give the new Pod time to start and to fail its readiness probe a few times.
for _ in $(seq 120); do
  [ "$(kubectl get pods -n donhang -l app=api --no-headers | wc -l)" -eq 3 ] && break
  sleep 1
done
sleep 40
# Newest last: running, not ready, never restarted.
show kubectl get pods -n donhang -l app=api --sort-by=.metadata.creationTimestamp
echo
# The Service sends requests only to the two ready Pods.
echo "\$ kubectl describe service api -n donhang | grep Endpoints"
kubectl describe service api -n donhang | grep Endpoints
echo "== GET http://api:8080/api/v1/products, from a temporary Pod in donhang"
# (When the Pod ends before kubectl attaches to it, kubectl warns and reads
# its log instead: the same output, so the warning is dropped.)
kubectl run readiness-test --rm -i --restart=Never --quiet -n donhang --image=caddy:2.10.0 -- \
  sh -c 'wget -q -O /dev/null http://api:8080/api/v1/products && echo "answered 2xx"' 2>&1 | sed "/^warning: couldn't attach/d"
echo
# A Pod counts as available only once it is ready: the update never finishes.
show kubectl rollout status deployment/api -n donhang --timeout=10s || true
echo

# Back to the manifest in Git.
show kubectl apply -f deploy/k8s/api.yaml
kubectl rollout status deployment/api -n donhang --timeout=300s >/dev/null

#!/usr/bin/env bash
# Call the api's /health/live and /health/ready through its Service, then on a second api Pod that cannot reach PostgreSQL.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the kind cluster from here.
set -euo pipefail
image=ghcr.io/duyan11110/donhang-api:1.0.0
# Sends GET http://<host>:8080<path> from a temporary Pod with BusyBox's wget,
# and prints the status line of the answer, then its body if it was a 2xx
# (for any other status, BusyBox's wget saves no body).
get() {
  local url="http://$1:8080$2"
# (When the Pod ends before kubectl attaches to it, kubectl warns and reads
# its log instead: the same output, so the warning is dropped.)
  kubectl run health-test --rm -i --restart=Never --quiet -n donhang --image=caddy:2.10.0 -- \
    sh -c "wget -S -q -O /tmp/body $url 2>/tmp/headers; grep '^  HTTP/' /tmp/headers | sed 's/^ *//'; [ -s /tmp/body ] && cat /tmp/body && echo; true" 2>&1 | sed "/^warning: couldn't attach/d"
}

if ! kubectl get service api -n donhang >/dev/null 2>&1; then
  echo "The backend is not deployed: run scripts/k8s/deploy.sh first." >&2
  exit 1
fi

# lesson: k8s.l1.health-endpoints
# /health/live runs no check; /health/ready asks EF Core to reach PostgreSQL.
echo "== GET http://api:8080/health/live"
get api /health/live
echo "== GET http://api:8080/health/ready"
get api /health/ready
echo

# The same image in a Pod of its own, given a database host that does not
# exist (db-missing). Its process runs; PostgreSQL cannot be reached.
kubectl delete pod api-no-db -n donhang --ignore-not-found >/dev/null
kubectl run api-no-db -n donhang --image="$image" --restart=Never \
  --env='ConnectionStrings__Default=Host=db-missing;Database=donhang;Username=donhang' \
  --env='ConnectionStrings__Redis=redis:6379,abortConnect=false' \
  --env='Keycloak__Authority=http://localhost:8180/realms/donhang' >/dev/null
kubectl wait --for=condition=Ready pod/api-no-db -n donhang --timeout=120s >/dev/null
ip=$(kubectl get pod api-no-db -n donhang -o jsonpath='{.status.podIP}')
for _ in $(seq 30); do
  get "$ip" /health/live 2>/dev/null | grep -q Healthy && break
  sleep 1
done
echo "== GET http://<IP of api-no-db>:8080/health/live"
get "$ip" /health/live
echo "== GET http://<IP of api-no-db>:8080/health/ready"
get "$ip" /health/ready
kubectl delete pod api-no-db -n donhang >/dev/null

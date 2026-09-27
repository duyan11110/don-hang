#!/usr/bin/env bash
# Deploy the Đơn Hàng backend to the kind cluster, in order: namespace, Secrets, ConfigMaps, PostgreSQL, Redis, Keycloak, Mailpit, the migration, then the api.
# Runs on the host, like every script in scripts/k8s/: it reads .env and db/ here and kubectl talks to the kind cluster from here.
set -euo pipefail
cd "$(dirname "$0")/../.."

# lesson: k8s.l1.deploying-don-hang
# Every step can run again: apply leaves what is already there unchanged.
# -o name prints each object once, whether it was created or not.
echo "== namespace"
kubectl apply -f deploy/k8s/namespace.yaml -o name

echo "== Secrets, from .env (scripts/k8s/secrets.sh)"
scripts/dev-secrets.sh >/dev/null
scripts/k8s/secrets.sh >/dev/null
kubectl get secrets -n donhang -o name

# lesson: k8s.l1.configmap-files
# The init scripts for PostgreSQL and the realm for Keycloak, built from the
# files in this repository; the numbers keep the order Compose runs them in.
echo "== ConfigMaps"
kubectl create configmap db-init -n donhang \
  --from-file=10-schema.sql=db/schema.sql \
  --from-file=20-seed.sql=db/seed.sql \
  --from-file=30-migrations-baseline.sql=db/migrations-baseline.sql \
  --dry-run=client -o yaml | kubectl apply -f - -o name
kubectl create configmap keycloak-realm -n donhang \
  --from-file=donhang-realm.json=keycloak/donhang-realm.json \
  --dry-run=client -o yaml | kubectl apply -f - -o name
kubectl apply -f deploy/k8s/api-configmap.yaml -o name

# lesson: k8s.l1.deploying-don-hang
echo "== PostgreSQL, Redis, Keycloak and Mailpit, each with its Service"
kubectl apply -f deploy/k8s/db.yaml -f deploy/k8s/redis.yaml \
  -f deploy/k8s/keycloak.yaml -f deploy/k8s/mailpit.yaml -o name
kubectl wait --for=condition=Available deployment/db -n donhang --timeout=300s

# The migration runs once per deploy: a new Pod each time, and the api is
# applied only once it has ended Succeeded.
echo "== the migration"
kubectl delete pod migrate -n donhang --ignore-not-found >/dev/null
kubectl apply -f deploy/k8s/migrate/migrate-pod.yaml -o name
phase=Pending
for _ in $(seq 300); do
  phase=$(kubectl get pod migrate -n donhang -o jsonpath='{.status.phase}')
  [ "$phase" = Succeeded ] || [ "$phase" = Failed ] && break
  sleep 1
done
echo "pod/migrate ended: $phase"
if [ "$phase" != Succeeded ]; then
  kubectl logs pod/migrate -n donhang >&2 || true
  exit 1
fi

echo "== the api"
kubectl apply -f deploy/k8s/api.yaml -o name
kubectl rollout status deployment/api -n donhang --timeout=300s | tail -n 1
# Keycloak is the slowest to start; nothing above waited for it.
kubectl wait --for=condition=Available deployment --all -n donhang --timeout=600s

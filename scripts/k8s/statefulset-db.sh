#!/usr/bin/env bash
# Commit staging's db as a StatefulSet with a claim (base/db.yaml), then delete db-0 and find the seeded orders still there when it comes back.
# Runs on the host, like every script in scripts/k8s/: kubectl and git talk to donhang-staging and its Git server from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/gitops.sh
show() { echo "\$ $*"; "$@"; }
orders() { kubectl exec db-0 -n donhang -- psql -U donhang -d donhang -tAc 'SELECT count(*) FROM orders'; }
db_ip() { kubectl get pod db-0 -n donhang -o jsonpath='{.status.podIP}'; }

if [ ! -f "$config_repo/envs/staging/kustomization.yaml" ]; then
  echo "envs/staging is not a Kustomize overlay yet: run scripts/k8s/kustomize-config-repo.sh first" >&2
  exit 1
fi

echo "== db before: $(kubectl get deployment,statefulset -n donhang -o name | grep '/db$')"
echo

# lesson: k8s.l2.statefulsets
# One commit replaces the Deployment db, whose data lived in an emptyDir,
# with the StatefulSet of base/db.yaml. Its first Pod, db-0, starts on an
# empty claim, so PostgreSQL runs the init scripts and seeds it once.
config_take base/db.yaml
git -C "$config_repo" diff --stat
config_commit statefulset-db.sh "db: a StatefulSet, its data on the claim data-db-0"
app_refresh
app_wait_sync "$(config_head --verify)" >/dev/null
app_wait Synced Healthy "$(config_head --verify)"
kubectl wait --for=condition=Ready pod/db-0 -n donhang --timeout=300s >/dev/null
show kubectl get statefulset,pods,pvc -n donhang -l app=db
show kubectl get pvc data-db-0 -n donhang
echo "orders: $(orders)"
echo

# lesson: k8s.l2.statefulsets
# The replacement is db-0 again, with a new IP address, and mounts the
# same claim: the data directory is not empty, so nothing is seeded again.
ip_before=$(db_ip)
show kubectl delete pod db-0 -n donhang
kubectl wait --for=condition=Ready pod/db-0 -n donhang --timeout=300s >/dev/null
show kubectl get pods -n donhang -l app=db
echo "same IP address as before: $([ "$(db_ip)" = "$ip_before" ] && echo yes || echo no)"
echo "orders: $(orders)"
echo "== the new db-0's log"
kubectl logs db-0 -n donhang | grep -e 'Skipping initialization' -e 'database system is ready'

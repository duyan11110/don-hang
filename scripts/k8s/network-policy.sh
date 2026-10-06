#!/usr/bin/env bash
# Connect from a Pod in security-lessons to staging's db, commit staging's NetworkPolicies (base/network-policies.yaml), and connect again: refused now, while the api still reaches db.
# Runs on the host, like every script in scripts/k8s/: kubectl, git and curl talk to donhang-staging and its Git server from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/gitops.sh
source scripts/lib/gateway.sh
show() { echo "\$ $*"; "$@"; }
# pg_isready from the Pod probe: does PostgreSQL answer on db.donhang:5432?
reach_db() {
  echo "\$ kubectl exec probe -n security-lessons -- pg_isready -h db.donhang.svc.cluster.local -t 5"
  kubectl exec probe -n security-lessons -- pg_isready -h db.donhang.svc.cluster.local -t 5 || true
}

if [ ! -f "$config_repo/envs/staging/kustomization.yaml" ]; then
  echo "envs/staging is not a Kustomize overlay yet: run scripts/k8s/kustomize-config-repo.sh first" >&2
  exit 1
fi
kubectl create namespace security-lessons --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl delete pod probe -n security-lessons --ignore-not-found --grace-period=1 >/dev/null
kubectl run probe -n security-lessons --image=postgres:17.6-alpine --command -- sleep 3600 >/dev/null
kubectl wait --for=condition=Ready pod/probe -n security-lessons --timeout=180s >/dev/null

# lesson: k8s.l3.network-policies
# No NetworkPolicy in donhang yet: a Pod in any namespace reaches any Pod,
# here PostgreSQL from security-lessons.
show kubectl get networkpolicies -n donhang
reach_db
echo

# The policies of base/network-policies.yaml, committed: every Pod in
# donhang isolated for ingress, then one policy per service. kindnet, kind's
# network plugin, carries them out.
config_take base/network-policies.yaml
config_commit network-policy.sh "NetworkPolicies: nothing reaches donhang's Pods but what each service needs"
app_refresh
app_wait_sync "$(config_head --verify)" >/dev/null
app_wait Synced Healthy "$(config_head --verify)"
show kubectl get networkpolicies -n donhang
echo

# lesson: k8s.l3.network-policies
# The same connection now gets no answer; the api, which the policy db
# names, still reads the database, and every Pod is still ready: the
# kubelet's probes come from the Pod's own node, which is always allowed.
reach_db
echo "== GET $gateway/api/v1/products (the api reads PostgreSQL)"
curl -s -o /dev/null -w 'HTTP %{http_code}\n' "$gateway/api/v1/products"
echo "== Pods in donhang not ready: $(kubectl get pods -n donhang --field-selector status.phase=Running \
  -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' | grep -c false || true)"

kubectl delete pod probe -n security-lessons --grace-period=1 --wait=false >/dev/null

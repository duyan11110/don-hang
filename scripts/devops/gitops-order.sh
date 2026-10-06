#!/usr/bin/env bash
# Show the sync waves in envs/staging, empty the namespace donhang and sync it again from nothing, then list when each step happened: database, migration hook, api.
# Runs on the host: kubectl talks to donhang-staging from here (after scripts/devops/gitops-first-sync.sh).
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/gitops.sh

sync_now() {
  kubectl patch application staging -n argocd --type merge \
    -p "{\"operation\":{\"initiatedBy\":{\"username\":\"gitops-order.sh\"},\"sync\":{\"revision\":\"main\"}}}" >/dev/null
  local phase=
  for _ in $(seq 900); do
    phase=$(kubectl get application staging -n argocd -o jsonpath='{.status.operationState.phase}')
    [ "$phase" = Running ] || break
    sleep 1
  done
  echo "sync: $phase"
}

# lesson: devops.l3.ordering-a-sync
# The order is written into the manifests: no annotation means wave 0.
echo "== sync waves and hooks in envs/staging"
grep -H -e 'argocd.argoproj.io/sync-wave' -e 'argocd.argoproj.io/hook' \
  deploy/gitops/config-repo/envs/staging/*.yaml | sed 's#deploy/gitops/config-repo/##; s/:  */: /'
echo

# Start from an empty namespace, as on the first sync: delete every object
# the Application manages (the Secrets go with their SealedSecrets).
echo "== emptying donhang"
kubectl delete deployments,services,sealedsecrets,pods --all -n donhang --wait=true >/dev/null
kubectl delete configmaps api db-init keycloak-realm -n donhang --ignore-not-found --wait=true >/dev/null
kubectl get all -n donhang 2>&1
echo

echo "== sync"
sync_now
app_wait Synced Healthy
echo

# When each step happened, read back from the objects themselves, then put
# in the order it happened (the times sort as text).
when() { kubectl get "$1" -n donhang -o jsonpath="$2"; }
{
  echo "$(when deployment/db '{.status.conditions[?(@.type=="Available")].lastTransitionTime}') wave 0: Deployment db available"
  echo "$(when deployment/keycloak '{.status.conditions[?(@.type=="Available")].lastTransitionTime}') wave 0: Deployment keycloak available"
  echo "$(when pod/migrate '{.status.containerStatuses[0].state.terminated.startedAt}') wave 1: hook Pod migrate started"
  echo "$(when pod/migrate '{.status.containerStatuses[0].state.terminated.finishedAt}') wave 1: hook Pod migrate ended $(when pod/migrate '{.status.phase}')"
  echo "$(when deployment/api '{.metadata.creationTimestamp}') wave 2: Deployment api created"
} | sort -s -k1,1 | cut -d' ' -f2- | nl -w1 -s'. '
echo

# lesson: devops.l3.ordering-a-sync
# The hook runs on every sync, also when nothing changed: a new migrate Pod
# (BeforeHookCreation deleted the old one), and a bundle that skips the
# migrations the database has recorded.
echo "== one more sync, with nothing changed"
before=$(when pod/migrate '{.metadata.uid}')
sync_now
after=$(when pod/migrate '{.metadata.uid}')
[ "$before" != "$after" ] && echo "a new Pod migrate ran: $(when pod/migrate '{.status.phase}')"
kubectl logs pod/migrate -n donhang | grep -v "^Acquiring"

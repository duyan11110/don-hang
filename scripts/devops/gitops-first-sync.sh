#!/usr/bin/env bash
# Apply the Application staging without a sync policy, see it OutOfSync, start one sync with kubectl, and watch it become Synced, then Healthy.
# Runs on the host: kubectl talks to donhang-staging from here (scripts/devops/argocd-install.sh and gitops-repo.sh come first).
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/gitops.sh

# What Argo CD reports for each object it manages: kind, name, sync, health.
resources() {
  kubectl get application staging -n argocd \
    -o jsonpath='{range .status.resources[*]}{.kind}/{.name}{"\t"}{.status}{"\t"}{.health.status}{"\n"}{end}' \
    | sort | column -t -s $'\t'
}

echo "== the Application, from deploy/gitops/lessons/staging-manual.yaml"
kubectl apply -f deploy/gitops/lessons/staging-manual.yaml -o name

# lesson: devops.l3.synced-versus-healthy
# Argo CD rereads the repository on an interval; a refresh asks it to
# compare now. With no sync policy it only reports what differs.
app_refresh
app_wait OutOfSync Missing "" 120
echo
resources
echo

# lesson: devops.l3.synced-versus-healthy
# A sync applies the folder's manifests. Without the argocd CLI, kubectl asks
# for one by writing an operation into the Application.
echo "== sync"
kubectl patch application staging -n argocd --type merge \
  -p '{"operation":{"initiatedBy":{"username":"gitops-first-sync.sh"},"sync":{"revision":"main"}}}' -o name
for _ in $(seq 900); do
  phase=$(kubectl get application staging -n argocd -o jsonpath='{.status.operationState.phase}')
  [ "$phase" = Succeeded ] || [ "$phase" = Failed ] || [ "$phase" = Error ] && break
  sleep 1
done
echo "sync: $phase"
# Right after the sync: every object matches Git, the api's new Pods are
# not ready yet.
kubectl get application staging -n argocd
kubectl get deployment api -n donhang
echo
app_wait Synced Healthy
kubectl get application staging -n argocd
kubectl get deployment api -n donhang
echo
resources
echo

# The namespace donhang came from OpenTofu's platform layer, not from the
# folder: Argo CD neither lists it nor reports it missing.
echo "== is the namespace donhang among the Application's objects?"
kubectl get application staging -n argocd -o jsonpath='{.status.resources[*].kind}' | tr ' ' '\n' \
  | grep -qx Namespace && echo yes || echo no

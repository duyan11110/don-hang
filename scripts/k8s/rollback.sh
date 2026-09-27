#!/usr/bin/env bash
# Apply an api tag that does not exist, see the update get stuck, undo it, then apply the 1.0.0 manifest again so the cluster matches Git.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the kind cluster from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }

# Start from two revisions: the sha- image, then 1.0.0 (scripts/k8s/rolling-update.sh).
kubectl apply -f deploy/k8s/namespace.yaml >/dev/null
kubectl delete deployment api -n donhang --ignore-not-found >/dev/null
kubectl wait --for=delete pod -l app=api -n donhang --timeout=120s >/dev/null 2>&1 || true
kubectl apply -f deploy/k8s/lessons/api-deployment.yaml >/dev/null
kubectl rollout status deployment/api -n donhang --timeout=300s >/dev/null
kubectl apply -f deploy/k8s/lessons/api-deployment-1.0.0.yaml >/dev/null
kubectl rollout status deployment/api -n donhang --timeout=300s >/dev/null

# lesson: k8s.l1.rollbacks
show kubectl rollout history deployment/api -n donhang
show kubectl apply -f deploy/k8s/lessons/api-deployment-bad-tag.yaml
# Wait until the kubelet has failed to pull the image and is waiting to try again.
for _ in $(seq 360); do
  kubectl get pods -n donhang -l app=api \
    -o jsonpath='{.items[*].status.containerStatuses[0].state.waiting.reason}' | grep -q ImagePullBackOff && break
  sleep 0.5
done
# The new Pod cannot start; both 1.0.0 Pods keep running.
show kubectl get pods -n donhang -l app=api --sort-by=.status.phase
# Kubernetes only waits: the update is stuck, not undone.
show kubectl rollout status deployment/api -n donhang --timeout=10s || true
echo

show kubectl rollout history deployment/api -n donhang
# Revision 2 (1.0.0) becomes current again, as revision 4.
show kubectl rollout undo deployment/api -n donhang
kubectl rollout status deployment/api -n donhang --timeout=300s >/dev/null
show kubectl rollout history deployment/api -n donhang
show kubectl get deployment api -n donhang -o wide
echo

# Git still says the bad tag was the last change applied: apply the 1.0.0
# manifest again, so that the manifest last applied is the one that runs.
show kubectl apply -f deploy/k8s/lessons/api-deployment-1.0.0.yaml
kubectl rollout status deployment/api -n donhang --timeout=300s >/dev/null

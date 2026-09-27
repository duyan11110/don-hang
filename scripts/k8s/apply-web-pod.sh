#!/usr/bin/env bash
# Apply the web Pod's manifest, wait for its container to run, then apply the same file again.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the kind cluster from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }

# Start from a cluster with no Pod named web, so the first apply creates it.
kubectl delete pod web --ignore-not-found >/dev/null

# lesson: k8s.l1.manifests-and-kubectl-apply
# apply returns as soon as the API server has stored the Pod; the container
# may not run yet. kubectl wait blocks until the Pod reports Ready.
show kubectl apply -f deploy/k8s/lessons/web-pod.yaml
show kubectl wait --for=condition=Ready pod/web --timeout=120s
show kubectl get pod web
echo

# The same file, unchanged: nothing new is created.
show kubectl apply -f deploy/k8s/lessons/web-pod.yaml

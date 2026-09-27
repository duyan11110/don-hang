#!/usr/bin/env bash
# Create the donhang namespace, then look for the web Pod with and without -n.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the kind cluster from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }

# The web Pod from scripts/k8s/apply-web-pod.sh must be there; and the
# namespace must not, so the apply below creates it.
kubectl apply -f deploy/k8s/lessons/web-pod.yaml >/dev/null
kubectl delete namespace donhang --ignore-not-found >/dev/null

# lesson: k8s.l1.namespaces
# Without -n, kubectl works in the current context's namespace: default.
show kubectl get pods
echo
show kubectl apply -f deploy/k8s/namespace.yaml
show kubectl get namespaces
echo
# The same name, looked up in another namespace, is another object.
show kubectl get pod web -n donhang || true

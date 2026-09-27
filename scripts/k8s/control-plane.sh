#!/usr/bin/env bash
# List the control plane's own Pods in kube-system, then show which node kube-scheduler chose for web.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the kind cluster from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }

kubectl apply -f deploy/k8s/lessons/web-pod.yaml >/dev/null
kubectl wait --for=condition=Ready pod/web --timeout=120s >/dev/null

# lesson: k8s.l1.control-plane-components
# The API server, etcd, kube-scheduler and kube-controller-manager run as
# Pods themselves. Only the ones on the control-plane node are listed here.
show kubectl get pods -n kube-system --field-selector spec.nodeName=donhang-control-plane
echo
# NODE: the worker kube-scheduler assigned web to; the kubelet there started it.
show kubectl get pod web -o wide

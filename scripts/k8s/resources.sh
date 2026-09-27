#!/usr/bin/env bash
# Show the api's CPU and memory requests and limits, then create a Pod that requests more CPU than any node has and see it stay Pending.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the kind cluster from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }

kubectl apply -f deploy/k8s/namespace.yaml >/dev/null
kubectl delete -f deploy/k8s/lessons/oversized-pod.yaml --ignore-not-found >/dev/null

# lesson: k8s.l1.requests-and-limits
if kubectl get deployment api -n donhang >/dev/null 2>&1; then
  echo "\$ kubectl get deployment api -n donhang -o jsonpath='{.spec.template.spec.containers[0].resources}'"
  kubectl get deployment api -n donhang -o jsonpath='{.spec.template.spec.containers[0].resources}'
  echo
  echo
fi

show kubectl apply -f deploy/k8s/lessons/oversized-pod.yaml
kubectl wait --for=jsonpath='{.status.conditions[0].reason}'=Unschedulable pod/oversized -n donhang --timeout=120s >/dev/null
# No node, no IP address: kube-scheduler has not assigned it anywhere.
show kubectl get pod oversized -n donhang -o wide
echo
echo "== why kube-scheduler placed it nowhere (its FailedScheduling event)"
kubectl get events -n donhang --field-selector involvedObject.name=oversized,reason=FailedScheduling \
  -o jsonpath='{.items[0].message}{"\n"}'
kubectl delete -f deploy/k8s/lessons/oversized-pod.yaml >/dev/null

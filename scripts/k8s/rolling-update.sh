#!/usr/bin/env bash
# Change the api's image tag from sha- to 1.0.0 and watch the Deployment move its Pods to a new ReplicaSet, a few at a time.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the kind cluster from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }

# Start from api-deployment.yaml alone: one revision, the sha- image.
kubectl apply -f deploy/k8s/namespace.yaml >/dev/null
kubectl delete deployment api -n donhang --ignore-not-found >/dev/null
kubectl wait --for=delete pod -l app=api -n donhang --timeout=120s >/dev/null 2>&1 || true
kubectl apply -f deploy/k8s/lessons/api-deployment.yaml >/dev/null
kubectl rollout status deployment/api -n donhang --timeout=300s >/dev/null
old_rs=$(kubectl get replicaset -n donhang -l app=api -o jsonpath='{.items[0].metadata.name}')

# lesson: k8s.l1.rolling-updates
# A new tag is a new Pod template: a new ReplicaSet is scaled up while the
# old one is scaled down. With 2 replicas, 25% maxSurge allows 1 Pod more
# than 2 (rounded up) and 25% maxUnavailable allows none fewer (rounded down).
show kubectl apply -f deploy/k8s/lessons/api-deployment-1.0.0.yaml

# Until the update is done, look at both ReplicaSets every moment: how many
# Pods each one wants and has ready.
both_ready=no
most_wanted=0
while :; do
  old_wanted=0 old_ready=0 new_wanted=0 new_ready=0
  while read -r name wanted ready; do
    if [ "$name" = "$old_rs" ]; then old_wanted=$wanted old_ready=${ready:-0}
    else new_wanted=$wanted new_ready=${ready:-0}; fi
  done < <(kubectl get replicaset -n donhang -l app=api \
             -o jsonpath='{range .items[*]}{.metadata.name} {.spec.replicas} {.status.readyReplicas}{"\n"}{end}')
  [ $((old_wanted + new_wanted)) -gt "$most_wanted" ] && most_wanted=$((old_wanted + new_wanted))
  [ "$old_ready" -ge 1 ] && [ "$new_ready" -ge 1 ] && both_ready=yes
  [ "$old_wanted" -eq 0 ] && [ "$new_ready" -eq 2 ] && break
  sleep 0.2
done
echo "While it ran: Pods of both versions were ready at the same time: $both_ready"
echo "While it ran: the most Pods both ReplicaSets wanted together: $most_wanted"
echo

show kubectl rollout status deployment/api -n donhang
# The old ReplicaSet stays, scaled to 0.
show kubectl get replicasets -n donhang -l app=api -o wide --sort-by=.spec.replicas

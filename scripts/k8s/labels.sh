#!/usr/bin/env bash
# Create three labelled Pods in donhang, then pick some of them out with label selectors.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the kind cluster from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }

kubectl apply -f deploy/k8s/namespace.yaml >/dev/null
kubectl delete -f deploy/k8s/lessons/labelled-pods.yaml --ignore-not-found >/dev/null

show kubectl apply -f deploy/k8s/lessons/labelled-pods.yaml
kubectl wait --for=condition=Ready pod --all -n donhang --timeout=120s >/dev/null
echo

# lesson: k8s.l1.labels
# --show-labels adds each Pod's labels as a last column. -l takes a label
# selector: only Pods whose labels match it are listed; with a comma, a Pod
# must match every condition.
show kubectl get pods -n donhang --show-labels
echo
show kubectl get pods -n donhang -l app=web
echo
show kubectl get pods -n donhang -l app=web,track=stable
echo
show kubectl get pods -n donhang -l track=stable

# The next lessons' ReplicaSet and Deployment select app=web: remove these.
kubectl delete -f deploy/k8s/lessons/labelled-pods.yaml >/dev/null

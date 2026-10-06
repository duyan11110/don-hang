#!/usr/bin/env bash
# Pod Security admission on donhang-staging: a Pod refused by the restricted namespace pod-security-lessons, the same template in a Deployment, a dry run of levels on donhang, and donhang's labels from OpenTofu.
# Runs on the host, like every script in scripts/k8s/: kubectl and OpenTofu talk to donhang-staging from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }
kubectl() { command kubectl --context kind-donhang-staging "$@"; }
kubectl delete namespace pod-security-lessons --ignore-not-found --wait=true >/dev/null

# lesson: k8s.l3.pod-security-admission
# A namespace labelled to enforce restricted, and a Pod with no
# securityContext at all: the API server refuses it and lists each check
# it fails. Nothing is created.
show kubectl apply -f deploy/k8s/lessons/restricted-namespace.yaml
echo "\$ kubectl run web --image=caddy:2.10.0 -n pod-security-lessons"
kubectl run web --image=caddy:2.10.0 -n pod-security-lessons 2>&1 | fold -s -w 120 || true
echo

# lesson: k8s.l3.pod-security-admission
# The same Pod template in a Deployment: the Deployment is accepted, since
# admission checks Pods, not what creates them. Its ReplicaSet's Pods are
# refused, and only the ReplicaSet's events say why.
echo "\$ kubectl create deployment web --image=caddy:2.10.0 -n pod-security-lessons"
kubectl create deployment web --image=caddy:2.10.0 -n pod-security-lessons 2>&1 | grep -v '^Warning'
sleep 5
show kubectl get deployment,replicaset,pods -n pod-security-lessons
echo "== the ReplicaSet's events"
kubectl get events -n pod-security-lessons --field-selector involvedObject.kind=ReplicaSet,reason=FailedCreate \
  -o jsonpath='{.items[-1:].message}{"\n"}' | sed -E 's/^\(combined from similar events\): //; s/^Error creating: //' | fold -s -w 120
echo

# lesson: k8s.l3.pod-security-admission
# --dry-run=server on an existing namespace: the API server lists the
# running Pods that a level would reject, and changes nothing. Staging's
# donhang passes baseline; restricted would reject the Pods whose images
# need more than it allows.
echo "\$ kubectl label --dry-run=server --overwrite namespace donhang pod-security.kubernetes.io/enforce=restricted"
kubectl label --dry-run=server --overwrite namespace donhang pod-security.kubernetes.io/enforce=restricted 2>&1 \
  | sed -E 's/^Warning: //'
echo "\$ kubectl label --dry-run=server --overwrite namespace donhang pod-security.kubernetes.io/enforce=baseline"
kubectl label --dry-run=server --overwrite namespace donhang pod-security.kubernetes.io/enforce=baseline 2>&1
echo

# donhang's labels come from OpenTofu (deploy/tofu/modules/donhang-platform):
# enforce baseline, warn and audit restricted. A plan finds nothing to change.
echo "== the labels of donhang"
kubectl get namespace donhang -o jsonpath='{.metadata.labels}{"\n"}' | tr ',' '\n'
echo "\$ scripts/devops/tofu-env.sh staging platform plan"
scripts/devops/tofu-env.sh staging platform plan -no-color -detailed-exitcode | grep -e '^No changes' -e '^Plan:'

kubectl delete namespace pod-security-lessons --wait=false >/dev/null

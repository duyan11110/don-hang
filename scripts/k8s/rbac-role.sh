#!/usr/bin/env bash
# Give junior-dev the Role pod-reader in security-lessons and ask kubectl auth can-i what it now may do there, in donhang, with Secrets and with delete; then see that listing Secrets shows their values.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to donhang-staging from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }
kubectl() { command kubectl --context kind-donhang-staging "$@"; }
can_i() { echo "\$ kubectl auth can-i $* --as=junior-dev"; kubectl auth can-i "$@" --as=junior-dev || true; }
kubectl create namespace security-lessons --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# lesson: k8s.l3.roles-and-role-bindings
# The Role and the RoleBinding of pod-reader-role.yaml: junior-dev may get,
# list and watch Pods in security-lessons. Nothing else, nowhere else.
show kubectl apply -f deploy/k8s/lessons/pod-reader-role.yaml
can_i list pods -n security-lessons
can_i list pods -n donhang
can_i list secrets -n security-lessons
can_i delete pods -n security-lessons
can_i create pods -n security-lessons
echo

# Listing Secrets returns them whole, values and all, not only their names:
# a right to list or watch Secrets is a right to read them. (Run as the
# administrator: junior-dev has no such right.)
kubectl create secret generic demo-secret -n security-lessons --from-literal=password=not-a-real-password \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
echo "\$ kubectl get secrets -n security-lessons -o jsonpath='{.items[*].data}'"
kubectl get secrets -n security-lessons -o jsonpath='{.items[*].data}'
echo
echo "the value, base64-decoded: $(kubectl get secret demo-secret -n security-lessons -o jsonpath='{.data.password}' | base64 -d)"
kubectl delete secret demo-secret -n security-lessons >/dev/null

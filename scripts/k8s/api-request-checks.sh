#!/usr/bin/env bash
# Show the API server's checks on donhang-staging: who kubectl signs in as, 401 for a credential it cannot verify, then can-i and 403 Forbidden for a user junior-dev in security-lessons.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to donhang-staging from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }
kubectl() { command kubectl --context kind-donhang-staging "$@"; }
kubectl create namespace security-lessons --dry-run=client -o yaml | kubectl apply -f - >/dev/null
# junior-dev starts with no binding (scripts/k8s/rbac-role.sh adds one).
kubectl delete -f deploy/k8s/lessons/pod-reader-role.yaml --ignore-not-found >/dev/null

# lesson: k8s.l3.api-request-checks
# Authentication: the API server keeps no list of users. kind's kubeconfig
# holds a client certificate, and the user and groups are whatever that
# certificate names.
show kubectl auth whoami
echo

# A credential the API server cannot verify: 401, before any rule is read.
# (An empty kubeconfig, so that only the made-up token is sent.)
server=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
empty=$(mktemp ./.empty-kubeconfig.XXXXXX)
echo "\$ kubectl get pods --token=not-a-real-token   (no certificate)"
command kubectl --kubeconfig="$empty" --server="$server" --insecure-skip-tls-verify --token=not-a-real-token \
  get pods -n security-lessons 2>&1 || true
rm -f "$empty"
echo

# lesson: k8s.l3.api-request-checks
# Authorization only: kubectl auth can-i asks whether a caller may do one
# verb on one kind of object in one namespace, and changes nothing. An
# administrator may ask on behalf of another user with --as.
show kubectl auth can-i create deployments -n security-lessons
show kubectl auth can-i create deployments -n security-lessons --as=junior-dev || true
show kubectl auth can-i list pods -n security-lessons --as=junior-dev || true
echo

# A known caller without permission: 403, which kubectl prints as Forbidden.
echo "\$ kubectl get pods -n security-lessons --as=junior-dev"
kubectl get pods -n security-lessons --as=junior-dev 2>&1 || true

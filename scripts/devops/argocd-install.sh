#!/usr/bin/env bash
# Install Argo CD 3.1 into the cluster donhang-staging from the pinned copy of its install manifest, wait until it runs, and list the new kinds of objects it adds.
# Runs on the host, like scripts/k8s/: kubectl talks to donhang-staging from here (scripts/devops/tofu-environments.sh creates it).
set -euo pipefail
cd "$(dirname "$0")/../.."
# Every kubectl below talks to donhang-staging, whatever context is current.
kubectl() { command kubectl --context kind-donhang-staging "$@"; }

# lesson: devops.l3.argo-cd-applications
# Argo CD cannot install itself: this script applies it, from the copy of its
# install manifest in deploy/argocd/ (version 3.1.16). Running it again with a
# changed copy is how Argo CD is upgraded.
echo "== Argo CD into the namespace argocd"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f - -o name
# One line per kind of object, with how many of that kind the manifest holds.
kubectl apply -n argocd -f deploy/argocd/install.yaml -o name | sed -E 's#/.*##' | sort | uniq -c
kubectl rollout status deployment --namespace argocd --timeout=600s >/dev/null
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=600s >/dev/null
echo

echo "== what runs it"
kubectl get deployments,statefulsets -n argocd
echo

# Applying it added kinds of objects the API server did not know before;
# kubectl now reads and applies an Application like a Deployment.
echo "== the kinds of objects Argo CD added"
kubectl api-resources --api-group=argoproj.io

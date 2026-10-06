#!/usr/bin/env bash
# Bind the built-in ClusterRole view to junior-dev in staging's donhang, ask what that allows, then read what Argo CD's controller may do.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to donhang-staging from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }
kubectl() { command kubectl --context kind-donhang-staging "$@"; }
can_i() { echo "\$ kubectl auth can-i $* --as=junior-dev"; kubectl auth can-i "$@" --as=junior-dev || true; }

# lesson: k8s.l3.cluster-roles
# view is a ClusterRole: no namespace of its own. The RoleBinding of
# junior-view-binding.yaml grants it in donhang only: Pods there, but not in
# kube-system, not Secrets, and not nodes, which belong to no namespace.
show kubectl apply -f deploy/k8s/lessons/junior-view-binding.yaml
can_i list pods -n donhang
can_i list deployments -n donhang
can_i list pods -n kube-system
can_i get secrets -n donhang
can_i list nodes
can_i delete pods -n donhang
echo

# lesson: k8s.l3.cluster-roles
# Argo CD's application controller: a ClusterRoleBinding gives its
# ServiceAccount a ClusterRole whose one rule allows every verb on every
# kind in every API group, so it can create whatever the config repository
# holds. Whoever can commit there can, too.
sa=system:serviceaccount:argocd:argocd-application-controller
echo "\$ kubectl get clusterrolebinding argocd-application-controller"
kubectl get clusterrolebinding argocd-application-controller \
  -o jsonpath='roleRef: {.roleRef.kind} {.roleRef.name}{"\n"}subject: {.subjects[0].kind} {.subjects[0].namespace}/{.subjects[0].name}{"\n"}'
echo "\$ kubectl get clusterrole argocd-application-controller"
kubectl get clusterrole argocd-application-controller \
  -o jsonpath='{range .rules[*]}apiGroups={.apiGroups} resources={.resources} nonResourceURLs={.nonResourceURLs} verbs={.verbs}{"\n"}{end}'
echo "can $sa create clusterrolebindings? $(kubectl auth can-i create clusterrolebindings --as="$sa" 2>/dev/null)"
echo "can $sa get secrets in kube-system? $(kubectl auth can-i get secrets -n kube-system --as="$sa")"

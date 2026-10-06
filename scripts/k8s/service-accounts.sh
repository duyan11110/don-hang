#!/usr/bin/env bash
# Look at ServiceAccounts on donhang-staging: the token Kubernetes mounts into a Pod, what default may do with it, and the api Pods, which get none.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to donhang-staging from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }
kubectl() { command kubectl --context kind-donhang-staging "$@"; }
# Paths like /var/run/secrets are paths inside the containers.
export MSYS_NO_PATHCONV=1
token_dir=/var/run/secrets/kubernetes.io/serviceaccount
kubectl create namespace security-lessons --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl delete -f deploy/k8s/lessons/token-pods.yaml --ignore-not-found --grace-period=1 >/dev/null

# Every namespace has a ServiceAccount named default, made by Kubernetes.
show kubectl get serviceaccounts -n security-lessons
echo

# lesson: k8s.l3.service-accounts
# Neither Pod names a ServiceAccount, so both run as default; only
# with-token has its token mounted, as a file the kubelet replaces before
# it expires.
show kubectl apply -f deploy/k8s/lessons/token-pods.yaml
kubectl wait --for=condition=Ready pod/with-token pod/without-token -n security-lessons --timeout=180s >/dev/null
echo "\$ kubectl exec with-token -- ls $token_dir"
kubectl exec with-token -n security-lessons -- ls "$token_dir"
echo "\$ kubectl exec without-token -- ls $token_dir"
kubectl exec without-token -n security-lessons -- ls "$token_dir" 2>&1 || true
echo

# lesson: k8s.l3.service-accounts
# In RBAC the ServiceAccount is the user system:serviceaccount:<namespace>:<name>.
# No binding names default here, so it may do next to nothing.
sa=system:serviceaccount:security-lessons:default
for check in "list pods" "get secrets" "create deployments"; do
  echo "can $sa $check? $(kubectl auth can-i $check -n security-lessons --as="$sa" || true)"
done
echo

# Whoever reads the token file can call the API server as that
# ServiceAccount: here from this machine, with no other credential.
token=$(kubectl exec with-token -n security-lessons -- cat "$token_dir/token")
server=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
empty=$(mktemp ./.empty-kubeconfig.XXXXXX)
echo "\$ kubectl auth whoami --token=<the token read from with-token>"
command kubectl --kubeconfig="$empty" --server="$server" --insecure-skip-tls-verify --token="$token" auth whoami \
  | grep -e Username -e Groups
rm -f "$empty"
echo

# The api, Notifications and Payments never call the API server: staging's
# base sets automountServiceAccountToken: false, and an api Pod has no token.
echo "\$ kubectl get deployment api -n donhang -o jsonpath='{.spec.template.spec.automountServiceAccountToken}'"
kubectl get deployment api -n donhang -o jsonpath='{.spec.template.spec.automountServiceAccountToken}{"\n"}'
echo "\$ kubectl exec deployment/api -n donhang -- ls $token_dir"
kubectl exec deployment/api -n donhang -- ls "$token_dir" 2>&1 || true

kubectl delete -f deploy/k8s/lessons/token-pods.yaml --grace-period=1 --wait=false >/dev/null

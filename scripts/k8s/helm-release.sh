#!/usr/bin/env bash
# Install the web chart as the release web in helm-lessons on donhang-staging, upgrade it, roll it back, then uninstall it, reading its history after each step.
# Runs on the host, like every script in scripts/k8s/: helm and kubectl talk to donhang-staging from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }
# Every helm and kubectl below talks to donhang-staging, whatever context is current.
helm() { command helm --kube-context kind-donhang-staging "$@"; }
kubectl() { command kubectl --context kind-donhang-staging "$@"; }
chart=deploy/helm/lessons/web
replicas() { kubectl get deployment web -n helm-lessons -o jsonpath='{.spec.replicas}'; }
# helm history without the UPDATED column, which changes on every run.
history() {
  echo "\$ helm history web -n helm-lessons"
  helm history web -n helm-lessons | awk -F'	' '{ gsub(/ +/, " "); print $1 "	" $3 "	" $4 "	" $6 }' | column -t -s $'	'
}

# A run that stopped halfway left the release behind.
helm uninstall web -n helm-lessons --wait >/dev/null 2>&1 || true
kubectl create namespace helm-lessons --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# lesson: k8s.l2.helm-releases
# install renders the chart, applies the result and records revision 1 of
# the release web; upgrade does the same with new values, as revision 2.
echo "\$ helm install web $chart -n helm-lessons --wait"
helm install web "$chart" -n helm-lessons --wait | grep -e '^NAME' -e '^REVISION' -e '^STATUS'
echo "replicas: $(replicas)"
echo "\$ helm upgrade web $chart -n helm-lessons --set replicas=2 --wait"
helm upgrade web "$chart" -n helm-lessons --set replicas=2 --wait | grep -e '^REVISION' -e '^STATUS'
echo "replicas: $(replicas)"
echo
history
echo

# The release's history lives in the cluster: one Secret per revision, in
# the release's namespace, holding that revision's manifests and values.
echo "== Secrets in helm-lessons"
show kubectl get secrets -n helm-lessons -o custom-columns=NAME:.metadata.name,TYPE:.type
echo

# lesson: k8s.l2.helm-releases
# rollback applies revision 1's manifests again, as a new revision 3;
# revision 2 stays in the history. values.yaml and this repository do not
# change: only the cluster does.
show helm rollback web 1 -n helm-lessons --wait
echo "replicas: $(replicas)"
history
echo

# uninstall deletes the release's objects and its history Secrets.
show helm uninstall web -n helm-lessons --wait
echo "== left in helm-lessons"
kubectl get deployments,services,secrets -n helm-lessons 2>&1

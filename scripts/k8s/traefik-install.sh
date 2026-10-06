#!/usr/bin/env bash
# Install Traefik into donhang-staging through Argo CD: the Gateway API kinds first, then the Application apps/traefik.yaml from the config repository; then diff two versions of the chart as a review would.
# Runs on the host, like every script in scripts/k8s/: kubectl, helm and git talk to donhang-staging and its Git server from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/gitops.sh
helm() { command helm --kube-context kind-donhang-staging "$@"; }
show() { echo "\$ $*"; "$@"; }
[ -d "$config_repo/.git" ] || scripts/devops/gitops-repo.sh >/dev/null
chart_repo=https://traefik.github.io/charts

# Gateway API's kinds of objects are not part of Kubernetes, and Traefik's
# chart does not bring them: they are installed from the pinned copy of the
# project's standard channel, server-side because the definitions are too
# big for the annotation a client-side apply writes.
echo "== the Gateway API kinds (v1.6.2, standard channel)"
kubectl apply --server-side -f deploy/gateway-api/standard-install.yaml -o name | sed -E 's#^([a-z]+)[^/]*/#\1 #'
echo

# lesson: k8s.l2.charts-through-argo-cd
# Installing Traefik is a commit of apps/traefik.yaml to the config
# repository, then applying that Application once; Argo CD renders the chart
# at the version the file names and syncs the result.
mkdir -p "$config_repo/apps"
cp deploy/gitops/config-repo/apps/traefik.yaml "$config_repo/apps/traefik.yaml"
if [ -n "$(git -C "$config_repo" status --porcelain)" ]; then
  config_commit traefik-install.sh "Traefik from its chart, version 41.6.1"
fi
show kubectl apply -f "$config_repo/apps/traefik.yaml"
app=traefik
app_wait Synced Healthy
kubectl rollout status deployment/traefik -n traefik --timeout=300s >/dev/null
echo

echo "== what the chart created in traefik"
kubectl get deployments,services -n traefik
echo "== the classes Ingress and Gateway objects can name"
kubectl get ingressclasses,gatewayclasses
echo

# Argo CD rendered the chart like helm template: there is no Helm release,
# and the helm command cannot upgrade or roll back what Argo CD synced.
echo "== Helm releases in the cluster"
show helm list --all-namespaces
echo

# The keys the chart accepts, each with its default: the Application above
# sets five of them.
echo "== helm show values: $(command helm show values traefik --repo "$chart_repo" --version 41.6.1 | grep -c '^[a-zA-Z]') top-level keys, $(command helm show values traefik --repo "$chart_repo" --version 41.6.1 | wc -l) lines"
echo

# lesson: k8s.l2.charts-through-argo-cd
# Review before a chart version changes: render the version before the pin
# and the pinned one with the same values, and diff. Each line below is one
# change of the rendered manifests, with how often it occurs.
values=$(mktemp)
kubectl create --dry-run=client -f "$config_repo/apps/traefik.yaml" -o jsonpath='{.spec.source.helm.valuesObject}' > "$values"
render() { command helm template traefik traefik --repo "$chart_repo" --version "$1" -n traefik -f "$values"; }
echo "== helm template 41.4.0 against 41.6.1"
diff <(render 41.4.0) <(render 41.6.1) | grep '^[<>]' | sed -E 's/^([<>]) +/\1 /' | sort | uniq -c || true
rm -f "$values"

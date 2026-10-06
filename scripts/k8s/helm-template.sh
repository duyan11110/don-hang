#!/usr/bin/env bash
# Render the web chart with helm template: with its defaults, with a values file, with --set on top; no cluster involved.
# Runs on the host, like every script in scripts/k8s/: helm runs from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }
chart=deploy/helm/lessons/web
# The rendered Deployment without the chart's comments.
deployment() { "$@" --show-only templates/deployment.yaml | grep -v -e '^#' -e '^---'; }

echo "== the chart: Chart.yaml, values.yaml and templates/"
find "$chart" -type f | sort
echo

# lesson: k8s.l2.helm-charts
# helm template renders the chart into plain manifests and prints them. It
# reads no kubeconfig: KUBECONFIG points at a file that does not exist, and
# the render works the same. The values come from values.yaml, then from -f,
# then from --set, each overriding the one before.
export KUBECONFIG=/nonexistent/kubeconfig
echo "== defaults (values.yaml)"
deployment show helm template web "$chart"
echo
echo "== -f deploy/helm/lessons/web-three-replicas.yaml"
deployment helm template web "$chart" -f deploy/helm/lessons/web-three-replicas.yaml | grep -e 'replicas:' -e 'image:'
echo
echo "== the same, plus --set replicas=5 --set image.tag=2.10.2"
deployment helm template web "$chart" -f deploy/helm/lessons/web-three-replicas.yaml \
  --set replicas=5 --set image.tag=2.10.2 | grep -e 'replicas:' -e 'image:'
echo

# --set changed the render only: values.yaml still holds the defaults.
echo "== values.yaml after both renders"
grep -v '^#' "$chart/values.yaml"
echo

# Templates are text: a value that breaks the YAML is found only by
# rendering, here a replica count that is not a number.
echo "== --set replicas=two"
deployment helm template web "$chart" --set replicas=two | grep 'replicas:'
echo "(helm template printed it; the API server would refuse a Deployment whose replicas is a string)"

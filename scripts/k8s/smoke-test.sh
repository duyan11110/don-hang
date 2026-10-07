#!/usr/bin/env bash
# List the backend's Pods, then call GET /api/v1/products through the api Service from a temporary Pod inside the cluster.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the kind cluster from here.
set -euo pipefail
show() { echo "\$ $*"; "$@"; }

if ! kubectl get service api -n donhang >/dev/null 2>&1; then
  echo "The backend is not deployed: run scripts/k8s/deploy.sh first." >&2
  exit 1
fi

# lesson: k8s.l1.deploying-don-hang
# migrate shows Completed: it ran once and stopped, as restartPolicy: Never says.
show kubectl get pods -n donhang
echo

# Nothing outside the cluster reaches the api. A Pod inside it asks the
# Service api by name; wget exits non-zero (and so does this script) unless
# the answer is a 2xx.
echo "== GET http://api:8080/api/v1/products, from a temporary Pod in donhang"
# (The Pod's shell first reads a line from stdin, which reaches it only once
# kubectl has attached: otherwise its first output could come too early.)
echo | kubectl run smoke-test --rm -i --restart=Never --quiet -n donhang --image=caddy:2.10.0 -- \
  sh -c 'read -r -t 60 _; wget -q -O - http://api:8080/api/v1/products' 2>&1
echo

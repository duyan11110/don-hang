#!/usr/bin/env bash
# List the files the ConfigMap db-init puts in the db container, and show PostgreSQL running them on its first start.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the kind cluster from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1
show() { echo "\$ $*"; "$@"; }

if ! kubectl get configmap db-init -n donhang >/dev/null 2>&1; then
  echo "The backend is not deployed: run scripts/k8s/deploy.sh first." >&2
  exit 1
fi

# lesson: k8s.l1.configmap-files
# One key per file of db/ that deploy.sh read; each key is a file name.
show kubectl get configmap db-init -n donhang
echo
# Mounted on /docker-entrypoint-initdb.d: one file per key, nothing else.
show kubectl exec deployment/db -n donhang -- ls /docker-entrypoint-initdb.d
show kubectl exec deployment/db -n donhang -- head -n 4 /docker-entrypoint-initdb.d/10-schema.sql
echo
# The data directory was empty when this db Pod started, so the image ran them.
echo "\$ kubectl logs deployment/db -n donhang | grep 'running /docker-entrypoint-initdb.d'"
kubectl logs deployment/db -n donhang | grep 'running /docker-entrypoint-initdb.d'

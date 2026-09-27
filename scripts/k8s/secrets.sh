#!/usr/bin/env bash
# Create the Secrets db, api and keycloak in donhang from .env, then see what describe shows and how easily a value is decoded.
# Runs on the host, like every script in scripts/k8s/: it reads .env here and kubectl talks to the kind cluster from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }

if [ ! -f .env ]; then
  echo ".env is missing: run scripts/dev-secrets.sh first." >&2
  exit 1
fi
# Read the values from .env without printing them.
set -a
. ./.env
set +a
kubectl apply -f deploy/k8s/namespace.yaml >/dev/null

# lesson: k8s.l1.secrets
# No Secret manifest exists in Git: each Secret is built here from .env and
# sent to the API server. `create --dry-run=client -o yaml` only writes the
# object out; `apply` creates it, or updates it when .env has changed.
secret() {
  local name=$1
  shift
  kubectl create secret generic "$name" -n donhang "$@" --dry-run=client -o yaml \
    | kubectl apply -f - -o name
}
echo "== Secrets from .env"
secret db --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD"
secret api --from-literal=ConnectionStrings__Default="Host=db;Database=donhang;Username=donhang;Password=$POSTGRES_PASSWORD"
secret keycloak --from-literal=KC_BOOTSTRAP_ADMIN_PASSWORD="$KEYCLOAK_ADMIN_PASSWORD"
echo

# describe prints only the size of each value...
show kubectl describe secret db -n donhang
echo
# ...but whoever may read the Secret gets its value, base64-encoded. That is
# an encoding, not encryption: base64 -d reverses it with no key. (The value
# here is the fake password scripts/dev-secrets.sh writes to every .env.)
echo "\$ kubectl get secret db -n donhang -o jsonpath='{.data.POSTGRES_PASSWORD}'"
kubectl get secret db -n donhang -o jsonpath='{.data.POSTGRES_PASSWORD}'
echo
echo "\$ kubectl get secret db -n donhang -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d"
kubectl get secret db -n donhang -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d
echo

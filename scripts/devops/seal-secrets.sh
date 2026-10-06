#!/usr/bin/env bash
# Seal the Secrets db, api and keycloak from .env with the certificate in secrets/, offline, into envs/staging of the config repository, then commit and push them.
# Runs on the host: it reads .env and secrets/ here and pushes to the Git server in donhang-staging through a port-forward.
# --no-commit only writes the files (scripts/devops/gitops-repo.sh and rotate-db-password.sh commit them with other changes).
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/gitops.sh

if [ ! -d "$config_repo/.git" ]; then
  echo "no working clone in $config_repo: run scripts/devops/gitops-repo.sh first" >&2
  exit 1
fi

# lesson: devops.l3.sealed-secrets
# Build each Secret as before (scripts/k8s/secrets.sh), but instead of sending
# it to the cluster, encrypt it with the certificate: kubeseal --cert needs
# no connection to the cluster. The SealedSecret goes into the config
# repository; only the controller's private key can turn it back.
seal() {
  local name=$1
  shift
  kubectl create secret generic "$name" -n donhang "$@" --dry-run=client -o yaml \
    | kubeseal --cert secrets/sealing.crt --format yaml > "$config_repo/envs/staging/sealed-$name.yaml"
  echo "sealed $name into envs/staging/sealed-$name.yaml"
}
# Staging's database password: the one in .env, until
# scripts/devops/rotate-db-password.sh gives staging one of its own.
db_password=${STAGING_POSTGRES_PASSWORD:-$POSTGRES_PASSWORD}
seal db --from-literal=POSTGRES_PASSWORD="$db_password"
seal api --from-literal=ConnectionStrings__Default="Host=db;Database=donhang;Username=donhang;Password=$db_password"
seal keycloak --from-literal=KC_BOOTSTRAP_ADMIN_PASSWORD="$KEYCLOAK_ADMIN_PASSWORD"
[ "${1:-}" = --no-commit ] && exit 0
echo

# What the repository now holds for db: ciphertext only (cut short here).
echo "== envs/staging/sealed-db.yaml"
sed -E 's/^(    POSTGRES_PASSWORD: .{24}).*/\1.../' "$config_repo/envs/staging/sealed-db.yaml"
echo

config_commit seal-secrets.sh "Seal the Secrets db, api and keycloak again"
echo "pushed $(config_head)"
app_refresh
app_wait_sync "$(config_head --verify)" >/dev/null
app_wait Synced Healthy "$(config_head --verify)" >/dev/null
echo
echo "== the Secrets the controller made from them, read by the Pods as before"
kubectl get secrets -n donhang -o custom-columns=NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].kind

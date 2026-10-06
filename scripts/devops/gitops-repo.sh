#!/usr/bin/env bash
# Start the Git server inside donhang-staging and push the config repository to it: deploy/gitops/config-repo, plus the SealedSecrets of envs/staging.
# Runs on the host: it makes sure donhang-staging exists with OpenTofu, applies the Git server with kubectl and pushes through a port-forward.
set -euo pipefail
cd "$(dirname "$0")/../.."

# The cluster and its platform layer (namespace donhang, sealing key), then
# the Sealed Secrets controller, which the SealedSecrets below need.
# devops.l3.sealed-secrets explains both; nothing changes if they are there.
scripts/devops/tofu-env.sh staging up >/dev/null
source scripts/lib/gitops.sh
scripts/devops/sealed-secrets-install.sh --install-only >/dev/null

# lesson: devops.l3.argo-cd-applications
# The Git server: one Pod in the namespace git (deploy/gitops/git-server.yaml),
# and an admin user donhang who owns the repository donhang-config. The
# repository is public, so Argo CD reads it without credentials.
echo "== the Git server"
kubectl apply -f deploy/gitops/git-server.yaml -o name
git_server_open
kubectl exec -n git deployment/gitea -- gitea admin user create --admin --username donhang \
  --email donhang@donhang.example --password "$GITEA_ADMIN_PASSWORD" --must-change-password=false \
  >/dev/null 2>&1 || true
echo

if curl -fsS "$git_server/api/v1/repos/donhang/donhang-config" >/dev/null 2>&1; then
  echo "== donhang/donhang-config is already on the Git server; nothing pushed"
  [ -d "$config_repo/.git" ] || git_auth clone -q -c core.autocrlf=false "$git_server/$repo_path" "$config_repo"
else
  # The first commit: the folders of deploy/gitops/config-repo, and for
  # envs/staging the SealedSecrets that scripts/devops/seal-secrets.sh makes
  # from .env (they never go into Đơn Hàng's own repository).
  rm -rf "$config_repo"
  mkdir -p "$config_repo"
  git init -q -b main "$config_repo"
  # Commit the files as they are, whatever line endings this machine prefers.
  git -C "$config_repo" config core.autocrlf false
  cp -R deploy/gitops/config-repo/. "$config_repo/"
  scripts/devops/seal-secrets.sh --no-commit >/dev/null
  curl -fsS -u "donhang:$GITEA_ADMIN_PASSWORD" -H 'Content-Type: application/json' \
    -d '{"name":"donhang-config","private":false,"default_branch":"main"}' \
    "$git_server/api/v1/user/repos" >/dev/null
  config_commit gitops-repo.sh "Staging and production as Đơn Hàng runs them"
  echo "== pushed to donhang/donhang-config"
fi

echo "== what Argo CD will read: http://gitea.git.svc:3000/$repo_path"
git -C "$config_repo" log --format='%h %an: %s' -n 5
git -C "$config_repo" ls-files | sed 's/^/  /'

#!/usr/bin/env bash
# Disaster-recovery drill for staging: delete donhang-staging, rebuild it by the written steps (OpenTofu, controllers, Git server from the mirror clone, Argo CD), and time each step.
# Runs on the host: kind, OpenTofu, kubectl and git all run from here. It deletes donhang-staging and everything in it.
# --without-sealing-key rebuilds without the sealing key, to see what that loses.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/gitops.sh

without_key=no
[ "${1:-}" = --without-sealing-key ] && without_key=yes

timings=()
step_started=0
step() {
  finish_step
  echo "== $1"
  step_name=$1
  step_started=$SECONDS
}
finish_step() {
  [ "$step_started" -gt 0 ] && timings+=("$(( SECONDS - step_started )) s  $step_name")
  step_started=0
}

# Before the disaster: the backup of the config repository. The Git server
# keeps its repositories inside the cluster, so they die with it; this
# mirror clone is all that will come back, and commits pushed after it is
# taken are lost.
echo "== backup: mirror clone of the config repository"
if kubectl get deployment gitea -n git >/dev/null 2>&1; then
  git_server_open
  rm -rf "$config_mirror"
  git_auth clone -q --mirror "$git_server/$repo_path" "$config_mirror"
  git_server_close
elif [ -d "$config_mirror" ]; then
  echo "no Git server running: the mirror clone taken earlier is the backup"
else
  echo "no Git server and no mirror clone in $config_mirror: nothing to restore from" >&2
  exit 1
fi
git -C "$config_mirror" log -1 --format='newest commit in the mirror: %h %s' main
echo

# lesson: devops.l3.disaster-recovery-drill
# The disaster: the whole cluster is gone. Then the written steps, each
# timed: both OpenTofu layers, the controllers, the Git server with the
# repository from the mirror, and Argo CD's Application, until Healthy.
step "disaster: donhang-staging is destroyed, both layers"
scripts/devops/tofu-env.sh staging platform destroy -auto-approve -no-color | grep -e '^Destroy complete'
scripts/devops/tofu-env.sh staging cluster destroy -auto-approve -no-color | grep -e '^Destroy complete'
drill_started=$SECONDS

step "1. OpenTofu: the cluster layer, then the platform layer"
scripts/devops/tofu-env.sh staging up | grep -e '^Apply complete' -e '^Plan:'

step "2. controllers: Sealed Secrets, then Argo CD"
if [ "$without_key" = yes ]; then
  # As if secrets/sealing.key had been lost: the cluster has no copy of it.
  kubectl delete secret sealing-key -n kube-system
fi
scripts/devops/sealed-secrets-install.sh --install-only >/dev/null
scripts/devops/argocd-install.sh >/dev/null
echo "both running"

step "3. Git server, and the repository pushed back from the mirror"
kubectl apply -f deploy/gitops/git-server.yaml >/dev/null
git_server_open
kubectl exec -n git deployment/gitea -- gitea admin user create --admin --username donhang \
  --email donhang@donhang.example --password "$GITEA_ADMIN_PASSWORD" --must-change-password=false >/dev/null
curl -fsS -u "donhang:$GITEA_ADMIN_PASSWORD" -H 'Content-Type: application/json' \
  -d '{"name":"donhang-config","private":false,"default_branch":"main"}' \
  "$git_server/api/v1/user/repos" >/dev/null
git_auth -C "$config_mirror" push -q --mirror "$git_server/$repo_path"
echo "pushed $(git -C "$config_mirror" rev-parse --short main)"

step "4. Argo CD: the Application from apps/staging.yaml, until Healthy"
git -C "$config_mirror" show main:apps/staging.yaml | kubectl apply -f - -o name
if [ "$without_key" = yes ]; then
  # Without the key the controller cannot open the SealedSecrets: no Secret
  # db or api, so their Pods cannot start, and staging never gets Healthy.
  for _ in $(seq 600); do
    reason=$(kubectl get pods -n donhang -l app=db -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || true)
    [ "$reason" = CreateContainerConfigError ] && break
    sleep 1
  done
  finish_step
  echo
  echo "== what the controller says about the SealedSecret db"
  kubectl get sealedsecret db -n donhang -o jsonpath='{.status.conditions[0].message}{"\n"}'
  echo "== Secrets in donhang"
  kubectl get secrets -n donhang -o name | grep . || echo "none"
  echo "== db's Pod, waiting"
  kubectl get pods -n donhang -l app=db -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}{"
"}'
  echo "== the api (wave 2): never applied, the sync stops at wave 0"
  kubectl get deployment api -n donhang -o name 2>&1 || true
  echo
  echo "The drill failed: staging cannot be rebuilt without the sealing key."
  exit 0
fi
app_wait Synced Healthy "" 1200
finish_step
echo

# lesson: devops.l3.disaster-recovery-drill
# The measured RTO of staging: the sum of the steps after the disaster.
echo "== timings"
printf '%s\n' "${timings[@]:1}"
echo "total: $(( SECONDS - drill_started )) s from losing the cluster to Healthy"

#!/usr/bin/env bash
# Turn the config repository's envs/ into a Kustomize base and two overlays in one commit, and see what Argo CD finds different in staging before and after it syncs.
# Runs on the host, like every script in scripts/k8s/: kubectl and git talk to donhang-staging and its Git server from here.
# scripts/devops/gitops-repo.sh --reset goes back to the plain manifests.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/gitops.sh
show() { echo "\$ $*"; "$@"; }
[ -d "$config_repo/.git" ] || scripts/devops/gitops-repo.sh >/dev/null
api_configmaps() { kubectl get configmaps -n donhang -o name | grep -E '^configmap/api(-|$)' | sed 's#configmap/##'; }
api_replicasets() { kubectl get replicasets -n donhang -l app=api --no-headers 2>/dev/null | wc -l; }

if [ -f "$config_repo/envs/staging/kustomization.yaml" ]; then
  echo "envs/staging is already a Kustomize overlay; scripts/devops/gitops-repo.sh --reset goes back" >&2
  exit 1
fi
echo "== envs/staging before: plain manifests"
ls "$config_repo/envs/staging" | sed 's/^/  /'
echo

# lesson: k8s.l2.config-repo-overlays
# The conversion, one commit: staging's manifests move into base/ as they
# are, except api-configmap.yaml, which base/kustomization.yaml now
# generates; production's full copies go. Each folder of envs/ keeps only
# its kustomization.yaml and, for staging, its SealedSecrets.
mkdir -p "$config_repo/base"
for file in "$config_repo"/envs/staging/*.yaml; do
  case "$(basename "$file")" in
    sealed-*) ;;
    api-configmap.yaml) git -C "$config_repo" rm -q "envs/staging/api-configmap.yaml" ;;
    *) git -C "$config_repo" mv "envs/staging/$(basename "$file")" base/ ;;
  esac
done
git -C "$config_repo" rm -q -r envs/production
config_take
git -C "$config_repo" add -A
git -C "$config_repo" status --short | sed 's/^/  /'

# Argo CD's automated sync is paused for a moment, to read what it finds
# different before it syncs. The Application itself needs no change:
# Argo CD renders envs/staging with Kustomize as soon as it finds a
# kustomization.yaml there.
kubectl patch application staging -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":null}}}' >/dev/null
config_commit kustomize-config-repo.sh "envs/: a Kustomize base and an overlay per environment"
app_refresh
for _ in $(seq 120); do
  [ "$(kubectl get application staging -n argocd -o jsonpath='{.status.sync.revision}')" = "$(config_head --verify)" ] && break
  sleep 1
done
echo
echo "== what Argo CD finds different in staging, before syncing"
kubectl get application staging -n argocd \
  -o jsonpath='{range .status.resources[?(@.status=="OutOfSync")]}{.kind} {.name}{"\n"}{end}' | sort
echo

# Automated sync on again, as apps/staging.yaml has it.
replicasets_before=$(api_replicasets)
kubectl apply -f "$config_repo/apps/staging.yaml" >/dev/null
app_wait_sync "$(config_head --verify)" >/dev/null
app_wait Synced Healthy "$(config_head --verify)"
kubectl rollout status deployment/api -n donhang --timeout=300s >/dev/null
echo "== after the sync"
echo "the api's ConfigMap: $(api_configmaps)"
echo "new ReplicaSets of the api: $(( $(api_replicasets) - replicasets_before ))"
echo

echo "== the config repository now"
git -C "$config_repo" ls-files | grep -v -e '^apps/' -e '^platform/' | sed 's/^/  /'

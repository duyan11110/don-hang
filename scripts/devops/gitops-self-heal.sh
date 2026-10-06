#!/usr/bin/env bash
# Scale the api by hand and remove a manifest from Git under automated sync alone, then turn on self-heal and prune with apps/staging.yaml and see both undone.
# Runs on the host: kubectl talks to donhang-staging from here, and the config repository is committed here (after scripts/devops/gitops-deploy.sh).
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/gitops.sh

replicas() { kubectl get deployment api -n donhang -o jsonpath='{.spec.replicas}'; }
sync_status() { kubectl get application staging -n argocd -o jsonpath='{.status.sync.status}'; }

# Automated sync without self-heal or prune, as gitops-deploy.sh left it.
kubectl apply -f deploy/gitops/lessons/staging-auto.yaml >/dev/null
app_wait Synced Healthy >/dev/null

# lesson: devops.l3.self-heal
# Automated sync alone acts on commits. A change made in the cluster leaves
# the Application OutOfSync, and the cluster as changed.
echo "== kubectl scale api to 4, with automated sync but no self-heal"
kubectl scale deployment api -n donhang --replicas=4
app_refresh
sleep 30
echo "30 s later: $(replicas) replicas, $(sync_status)"
echo

# A ConfigMap that exists only to be removed again: added in one commit,
# removed in the next. The first commit's sync applies the whole folder, so
# it also puts the api back to the replicas Git declares.
echo "== a ConfigMap added in Git, then removed from Git, without prune"
kubectl create configmap prune-demo -n donhang --from-literal=note="only here to be pruned" \
  --dry-run=client -o yaml > "$config_repo/envs/staging/prune-demo.yaml"
config_commit gitops-self-heal.sh "Add the ConfigMap prune-demo"
app_refresh
app_wait Synced Healthy "$(config_head --verify)" >/dev/null
echo "after the sync of that commit: $(replicas) replicas"
git -C "$config_repo" rm -q envs/staging/prune-demo.yaml
config_commit gitops-self-heal.sh "Remove the ConfigMap prune-demo"
app_refresh
# (No sync starts for this commit: all that differs is an object to prune.)
app_wait OutOfSync Healthy "$(config_head --verify)" >/dev/null
kubectl get configmap prune-demo -n donhang -o name
kubectl get application staging -n argocd \
  -o jsonpath='{range .status.resources[?(@.name=="prune-demo")]}{.kind}/{.name}: requiresPruning={.requiresPruning}{"\n"}{end}'
echo

# lesson: devops.l3.self-heal
# apps/staging.yaml turns on selfHeal and prune: the ConfigMap no longer in
# Git is deleted, and a hand-made scale lasts only until Argo CD notices it.
echo "== self-heal and prune, from config-repo/apps/staging.yaml"
kubectl apply -f "$config_repo/apps/staging.yaml" -o name
app_wait Synced Healthy
kubectl get configmap prune-demo -n donhang -o name 2>&1 || true
kubectl scale deployment api -n donhang --replicas=4
for _ in $(seq 120); do [ "$(replicas)" = 2 ] && break; sleep 1; done
app_wait Synced Healthy >/dev/null
kubectl rollout status deployment/api -n donhang --timeout=300s >/dev/null
echo "shortly after: $(replicas) replicas, $(sync_status)"

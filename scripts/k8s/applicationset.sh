#!/usr/bin/env bash
# Register donhang-north and donhang-south with the Argo CD of donhang-staging (a cluster Secret each, never in Git), commit platform/regions/ to the config repository, apply regions-appset.yaml and see one Application per region sync echo-region; commit a new answer and see both regions change; then delete the ApplicationSet, the cluster Secrets and platform/regions/.
# Runs on the host, like every script in scripts/k8s/: kind, kubectl, docker and git talk to donhang-staging, its Git server and the two region clusters from here. With donhang-staging and both regions running, Docker needs about 2 GB more memory than for staging alone.
set -euo pipefail
cd "$(dirname "$0")/../.."
# kubectl talks to donhang-staging; region <name> to a region's cluster.
source scripts/lib/gitops.sh
source scripts/lib/regions.sh
regions_up
if [ ! -d "$config_repo/.git" ]; then
  echo "no working clone of the config repository: run scripts/devops/gitops-repo.sh first" >&2
  exit 1
fi
git -C "$config_repo" pull -q --ff-only 2>/dev/null || true

# regions_commit <message>: commit platform/regions/ (and only that) and
# push it; if another commit reached the server first, rebase onto it.
regions_commit() {
  # (After git rm the folder is gone, and its removal already staged.)
  [ ! -d "$config_repo/platform/regions" ] || git -C "$config_repo" add -A platform/regions
  git -C "$config_repo" -c user.name=applicationset.sh -c user.email=lab@donhang.example commit -q -m "$1"
  git_server_open
  if ! git_auth -C "$config_repo" push -q "$git_server/$repo_path" main 2>/dev/null; then
    git_auth -C "$config_repo" pull -q --rebase "$git_server/$repo_path" main
    git_auth -C "$config_repo" push -q "$git_server/$repo_path" main
  fi
}
# Whatever happens, the lab leaves nothing behind in staging: no
# ApplicationSet, no cluster Secret, no platform/regions/.
cleanup() {
  kubectl delete -f deploy/gitops/lessons/regions-appset.yaml --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete secret -n argocd -l donhang.lab/region=true --ignore-not-found >/dev/null 2>&1 || true
  if [ -d "$config_repo/platform/regions" ]; then
    git -C "$config_repo" rm -rq platform/regions
    regions_commit "regions: removed after the lab" || true
  fi
  git_server_close
}
trap cleanup EXIT
cleanup
trap cleanup EXIT

# lesson: k8s.l4.one-argo-cd-many-clusters
# A cluster Secret per region in argocd: the API server's address inside
# Docker's network kind (where staging's node runs too) and the region's
# admin certificate and key, from kind's kubeconfig for that network. It is
# made here, from secrets/, and never written to Git.
for name in "${regions[@]}"; do
  internal=secrets/regions-$name-internal.kubeconfig
  kind get kubeconfig --name "donhang-$name" --internal > "$internal"
  field() { command kubectl config view --kubeconfig "$internal" --raw -o jsonpath="{.$1}"; }
  config=$(printf '{"tlsClientConfig":{"caData":"%s","certData":"%s","keyData":"%s"}}' \
    "$(field 'clusters[0].cluster.certificate-authority-data')" \
    "$(field 'users[0].user.client-certificate-data')" "$(field 'users[0].user.client-key-data')")
  rm -f "$internal"
  echo "\$ kubectl create secret generic region-$name -n argocd --from-literal=name=donhang-$name --from-literal=server=https://donhang-$name-control-plane:6443 --from-literal=config=<its certificates>"
  kubectl create secret generic "region-$name" -n argocd --from-literal=name="donhang-$name" \
    --from-literal=server="https://donhang-$name-control-plane:6443" --from-literal=config="$config"
  show kubectl label secret "region-$name" -n argocd argocd.argoproj.io/secret-type=cluster donhang.lab/region=true
done
echo "\$ kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster -L donhang.lab/region"
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster -L donhang.lab/region \
  -o custom-columns='NAME:.metadata.name,TYPE:.type,REGION:.metadata.labels.donhang\.lab/region'
echo

# lesson: k8s.l4.one-argo-cd-many-clusters
# What the regions run, in the config repository beside staging's folders.
mkdir -p "$config_repo/platform/regions"
cp deploy/gitops/config-repo/platform/regions/echo-region.yaml "$config_repo/platform/regions/"
echo "\$ git add platform/regions && git commit -m 'regions: echo-region for every region' && git push"
regions_commit "regions: echo-region for every region"
echo

# lesson: k8s.l4.one-argo-cd-many-clusters
# The ApplicationSet: its controller makes one Application per cluster
# Secret with the label, and none for staging.
show kubectl apply -f deploy/gitops/lessons/regions-appset.yaml
for name in "${regions[@]}"; do
  until kubectl get application "echo-donhang-$name" -n argocd >/dev/null 2>&1; do sleep 2; done
done
for name in "${regions[@]}"; do
  app=echo-donhang-$name
  app_refresh
  app_wait Synced Healthy >/dev/null
done
echo "\$ kubectl get applications -n argocd -o custom-columns=NAME,DESTINATION,SYNC,HEALTH"
kubectl get applications -n argocd \
  -o custom-columns='NAME:.metadata.name,DESTINATION:.spec.destination.server,SYNC:.status.sync.status,HEALTH:.status.health.status' \
  | awk 'NR == 1 || /^echo-/ || $1 == "staging"'
echo

# lesson: k8s.l4.one-argo-cd-many-clusters
# Each region answers on its node port with its node's name.
for name in "${regions[@]}"; do
  echo "\$ docker exec donhang-$name-control-plane curl -s http://localhost:30090/"
  region_echo "$name"
  echo
done
echo

# lesson: k8s.l4.one-argo-cd-many-clusters
# One commit changes the answer: both Applications sync it, so both
# regions change together, as a mistake would.
sed -i 's/greetings from/hello from/' "$config_repo/platform/regions/echo-region.yaml"
echo "\$ git commit -am 'regions: say hello' && git push    (greetings from -> hello from)"
regions_commit "regions: say hello"
revision=$(git -C "$config_repo" rev-parse HEAD)
for name in "${regions[@]}"; do
  app=echo-donhang-$name
  app_refresh
  app_wait Synced Healthy "$revision"
done
for name in "${regions[@]}"; do
  region "$name" rollout status deployment/echo-region -n regions --timeout=180s >/dev/null
  until region_echo "$name" | grep -q '^hello'; do sleep 2; done
  echo "\$ docker exec donhang-$name-control-plane curl -s http://localhost:30090/"
  region_echo "$name"
  echo
done
echo

# lesson: k8s.l4.one-argo-cd-many-clusters
# The end of the lab: the ApplicationSet (its Applications go with it, and
# Argo CD deletes what they deployed in the regions), the cluster Secrets,
# platform/regions/.
trap - EXIT
cleanup
echo "deleted: ApplicationSet regions, Secrets region-north and region-south, platform/regions/"

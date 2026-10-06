#!/usr/bin/env bash
# Commit the ValidatingAdmissionPolicy require-image-digest with a Warn binding, check staging's running Pods against it, switch the binding to Deny, then try Pods that name the api image by tag and by digest.
# Runs on the host, like every script in scripts/k8s/: kubectl and git talk to donhang-staging and its Git server from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/gitops.sh
show() { echo "\$ $*"; "$@"; }
policy=deploy/gitops/config-repo/platform/policies/require-image-digest.yaml
# Without Pod Security's warnings (warn is restricted in donhang), which
# are not what this script is about.
quiet() { grep -v -e 'would violate PodSecurity' -e '^Warning: .*restricted'; }
sync_policies() {
  app=policies-staging
  app_refresh
  app_wait_sync "$(config_head --verify)" >/dev/null
  app_wait Synced Healthy "$(config_head --verify)"
}

# lesson: k8s.l3.admission-policies
# First the policy with its binding set to Warn: Pods that fail are still
# admitted, and the client gets a warning. The Application
# policies-staging syncs platform/policies from now on.
mkdir -p "$config_repo/platform/policies"
sed 's/validationActions: \["Deny"\]/validationActions: ["Warn"]/' "$policy" \
  > "$config_repo/platform/policies/require-image-digest.yaml"
cp deploy/gitops/config-repo/apps/policies-staging.yaml "$config_repo/apps/policies-staging.yaml"
if [ -n "$(git -C "$config_repo" status --porcelain)" ]; then
  config_commit admission-policy.sh "Admission policy require-image-digest, warning only"
fi
show kubectl apply -f "$config_repo/apps/policies-staging.yaml"
sync_policies
show kubectl get validatingadmissionpolicies,validatingadmissionpolicybindings
echo

# Which running Pods would fail? Send each one back unchanged with a dry
# run: an update is admitted again, and Warn prints the Pods that fail.
echo "== running Pods in donhang that the policy warns about"
warned=0
for pod in $(kubectl get pods -n donhang --field-selector status.phase=Running -o name); do
  if kubectl get "$pod" -n donhang -o yaml | kubectl replace --dry-run=server -f - 2>&1 | grep -q 'require-image-digest'; then
    echo "$pod"
    warned=$((warned + 1))
  fi
done
echo "$warned of $(kubectl get pods -n donhang --field-selector status.phase=Running -o name | wc -l) Pods"
echo

# lesson: k8s.l3.admission-policies
# None would fail, so the binding becomes Deny: a Pod that names the api's
# image by tag only is refused before it is stored.
cp "$policy" "$config_repo/platform/policies/require-image-digest.yaml"
config_commit admission-policy.sh "Admission policy require-image-digest: deny"
sync_policies
echo "\$ kubectl run api-by-tag -n donhang --image=ghcr.io/duyan11110/donhang-api:1.0.0 --dry-run=server"
kubectl run api-by-tag -n donhang --image=ghcr.io/duyan11110/donhang-api:1.0.0 --dry-run=server 2>&1 | quiet || true

# CEL sees only the object: any digest passes, even one that names no
# image in the registry, let alone a signed one.
fake=sha256:$(printf '0%.0s' $(seq 64))
echo "\$ kubectl run api-by-digest -n donhang --image=ghcr.io/duyan11110/donhang-api@$fake --dry-run=server"
kubectl run api-by-digest -n donhang --image="ghcr.io/duyan11110/donhang-api@$fake" --dry-run=server 2>&1 | quiet

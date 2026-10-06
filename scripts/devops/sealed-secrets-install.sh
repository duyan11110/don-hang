#!/usr/bin/env bash
# Install the Sealed Secrets controller into donhang-staging, show the one sealing key it uses, then show that a SealedSecret decrypts only in the namespace it was sealed for.
# Runs on the host: kubectl talks to donhang-staging from here, and kubeseal seals with the certificate in secrets/.
# --install-only stops after the install (scripts/devops/gitops-repo.sh and dr-drill.sh run it that way).
set -euo pipefail
cd "$(dirname "$0")/../.."
kubectl() { command kubectl --context kind-donhang-staging "$@"; }

# lesson: devops.l3.sealed-secrets
# OpenTofu's platform layer has already put the sealing key into kube-system;
# the controller, started after it, finds the key by its label and uses it.
echo "== the Sealed Secrets controller, from deploy/sealed-secrets/controller.yaml"
kubectl apply -f deploy/sealed-secrets/controller.yaml -o name
kubectl rollout status deployment/sealed-secrets-controller -n kube-system --timeout=300s | tail -n 1
[ "${1:-}" = --install-only ] && exit 0
echo

echo "== the sealing keys in kube-system: only the one from secrets/"
kubectl get secrets -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o custom-columns=NAME:.metadata.name,STATE:.metadata.labels.sealedsecrets\\.bitnami\\.com/sealed-secrets-key
echo

# lesson: devops.l3.sealed-secrets
# Seal a throwaway value for the name scope-demo in the namespace donhang,
# offline, with the certificate only. Applied there, it becomes a Secret.
# The same SealedSecret moved to another namespace decrypts to nothing: the
# name and namespace are part of what was encrypted.
kubectl create secret generic scope-demo -n donhang --from-literal=word=not-a-real-secret \
  --dry-run=client -o yaml | kubeseal --cert secrets/sealing.crt --format yaml > "${TMPDIR:-/tmp}/scope-demo.yaml"
kubectl create namespace sealing-demo --dry-run=client -o yaml | kubectl apply -f - >/dev/null
echo "== sealed for donhang, applied in donhang"
kubectl apply -f "${TMPDIR:-/tmp}/scope-demo.yaml" -o name
echo "== the same SealedSecret, applied in sealing-demo"
sed 's/namespace: donhang/namespace: sealing-demo/' "${TMPDIR:-/tmp}/scope-demo.yaml" | kubectl apply -f - -o name
sleep 5
echo
echo "== Secrets named scope-demo the controller made"
kubectl get secrets -A --field-selector metadata.name=scope-demo -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name
echo "== why sealing-demo has none"
kubectl get sealedsecret scope-demo -n sealing-demo -o jsonpath='{.status.conditions[0].message}{"\n"}'

# Leave nothing behind.
kubectl delete namespace sealing-demo --wait=false >/dev/null
kubectl delete sealedsecret scope-demo -n donhang >/dev/null
rm -f "${TMPDIR:-/tmp}/scope-demo.yaml"

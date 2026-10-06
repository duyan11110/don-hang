#!/usr/bin/env bash
# Install cert-manager 1.20.4 on donhang from the pinned copy of the manifest its project publishes (deploy/cert-manager/cert-manager.yaml), CRDs included, and wait until its three Deployments are ready.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster

# lesson: k8s.l3.cert-manager
# One manifest: cert-manager's kinds of objects (its CRDs), the namespace
# cert-manager, and three controllers there, each a Deployment: the
# controller that issues and renews certificates, the webhook the API
# server asks to check cert-manager's objects, and the cainjector.
echo "\$ kubectl apply -f deploy/cert-manager/cert-manager.yaml"
kubectl apply -f deploy/cert-manager/cert-manager.yaml | grep -E '^(namespace|deployment)'
for name in cert-manager cert-manager-cainjector cert-manager-webhook; do
  kubectl rollout status "deployment/$name" -n cert-manager --timeout=300s >/dev/null
done
show kubectl get deployments -n cert-manager \
  -o custom-columns=DEPLOYMENT:.metadata.name,READY:.status.readyReplicas,IMAGE:.spec.template.spec.containers[0].image
echo

# lesson: k8s.l3.cert-manager
# The kinds it brought: Issuer and Certificate are the two the lab uses.
echo "\$ kubectl get crds | grep cert-manager.io"
kubectl get crds -o custom-columns=NAME:.metadata.name | grep 'cert-manager\.io$'

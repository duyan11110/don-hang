#!/usr/bin/env bash
# Delete the Secret api-tls behind the Certificate api-cert (cert-manager.sh) and watch cert-manager issue a new certificate into a Secret of the same name; then ask what cert-manager's ServiceAccount may do with Secrets across the cluster.
# Runs on the host, like every script in scripts/k8s/: kubectl and openssl run here and talk to the cluster donhang.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster
kubectl get certificate api-cert -n operator-lessons >/dev/null 2>&1 || scripts/k8s/cert-manager.sh >/dev/null
kubectl wait --for=condition=Ready certificate/api-cert -n operator-lessons --timeout=120s >/dev/null
serial() { kubectl get secret api-tls -n operator-lessons -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -serial; }
before=$(serial)

# lesson: k8s.l3.operator-pattern
# Delete the Secret the Certificate api-cert names. Nobody tells
# cert-manager: on its next pass it finds the Certificate's Secret missing,
# and acts on the difference.
show kubectl delete secret api-tls -n operator-lessons
for _ in $(seq 60); do
  kubectl get secret api-tls -n operator-lessons >/dev/null 2>&1 && break
  sleep 1
done
kubectl wait --for=condition=Ready certificate/api-cert -n operator-lessons --timeout=120s >/dev/null
echo "\$ kubectl get secret api-tls -n operator-lessons"
kubectl get secret api-tls -n operator-lessons -o custom-columns=NAME:.metadata.name,TYPE:.type
echo

# lesson: k8s.l3.operator-pattern
# Same name, new certificate: cert-manager asked the Issuer once more, with
# the Certificate's second CertificateRequest (api-cert-2; right after
# cert-manager.sh, api-cert-1 issued the first certificate).
if [ "$(serial)" != "$before" ]; then echo "a new certificate: its serial number differs from the deleted one"; fi
show kubectl get certificaterequests -n operator-lessons \
  -o custom-columns=NAME:.metadata.name,ISSUER:.spec.issuerRef.name,READY:.status.conditions[?\(@.type==\"Ready\"\)].status
echo

# lesson: k8s.l3.operator-pattern
# To do that in every namespace, cert-manager's ServiceAccount may read
# every Secret in the cluster; a Pod's default ServiceAccount may not.
show kubectl auth can-i list secrets -A --as=system:serviceaccount:cert-manager:cert-manager
show kubectl auth can-i list secrets -A --as=system:serviceaccount:operator-lessons:default || true

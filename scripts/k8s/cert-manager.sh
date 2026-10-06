#!/usr/bin/env bash
# In operator-lessons on donhang: put the lab CA in the Secret lab-ca, apply the Issuer lab-ca (lab-ca-issuer.yaml) and the Certificate api-cert for donhang.localhost (api-certificate.yaml), wait for Ready, and read the Secret api-tls cert-manager wrote and the expiry and renewal time from the Certificate's status.
# Runs on the host, like every script in scripts/k8s/: kubectl and openssl run here and talk to the cluster donhang.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster
kubectl get deployment cert-manager-webhook -n cert-manager >/dev/null 2>&1 || scripts/k8s/cert-manager-install.sh >/dev/null
[ -f secrets/lab-ca.key ] || scripts/dev-secrets.sh >/dev/null
kubectl delete namespace operator-lessons --ignore-not-found --wait=true >/dev/null
kubectl create namespace operator-lessons >/dev/null
# Right after an install, cert-manager's webhook may take a few seconds
# before the API server can reach it: try again until it answers.
apply() {
  for _ in $(seq 30); do
    kubectl apply -f "$1" 2>/dev/null && return
    sleep 2
  done
  kubectl apply -f "$1"
}

# lesson: k8s.l3.cert-manager
# The lab CA's certificate and key, from secrets/ (never Git), into a
# Secret in the Issuer's namespace; then the Issuer that signs with it.
echo "\$ kubectl create secret tls lab-ca -n operator-lessons --cert=secrets/lab-ca.crt --key=secrets/lab-ca.key"
kubectl create secret tls lab-ca -n operator-lessons --cert=secrets/lab-ca.crt --key=secrets/lab-ca.key
echo "\$ kubectl apply -f deploy/k8s/lessons/lab-ca-issuer.yaml"
apply deploy/k8s/lessons/lab-ca-issuer.yaml
show kubectl wait --for=condition=Ready issuer/lab-ca -n operator-lessons --timeout=120s
echo

# lesson: k8s.l3.cert-manager
# The Certificate names the Issuer, the DNS name and the Secret; cert-manager
# does the rest. Ready means the signed certificate is in that Secret.
echo "\$ kubectl apply -f deploy/k8s/lessons/api-certificate.yaml"
apply deploy/k8s/lessons/api-certificate.yaml
show kubectl wait --for=condition=Ready certificate/api-cert -n operator-lessons --timeout=120s
show kubectl get certificate api-cert -n operator-lessons
echo

# lesson: k8s.l3.cert-manager
# The Secret api-tls: type kubernetes.io/tls, with tls.crt and tls.key
# (and ca.crt, the CA that signed it). The certificate in it is for
# donhang.localhost, signed by the lab CA.
echo "\$ kubectl get secret api-tls -n operator-lessons -o go-template='{{.type}}:{{range \$key, \$value := .data}} {{\$key}}{{end}}'"
kubectl get secret api-tls -n operator-lessons \
  -o go-template='{{.type}}:{{range $key, $value := .data}} {{$key}}{{end}}{{"\n"}}'
echo "\$ kubectl get secret api-tls -n operator-lessons -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -issuer -ext subjectAltName"
kubectl get secret api-tls -n operator-lessons -o jsonpath='{.data.tls\.crt}' | base64 -d \
  | openssl x509 -noout -issuer -ext subjectAltName | sed '/^$/d'
echo

# lesson: k8s.l3.cert-manager
# From the Certificate's status: when the certificate expires, and when
# cert-manager will renew it, well before that.
echo "\$ kubectl get certificate api-cert -n operator-lessons -o jsonpath='notBefore: {.status.notBefore}{\"\n\"}notAfter: {.status.notAfter}{\"\n\"}renewalTime: {.status.renewalTime}'"
kubectl get certificate api-cert -n operator-lessons \
  -o jsonpath='notBefore: {.status.notBefore}{"\n"}notAfter: {.status.notAfter}{"\n"}renewalTime: {.status.renewalTime}{"\n"}'
days() { echo $(( ($(date -d "$2" +%s) - $(date -d "$1" +%s)) / 86400 )); }
status() { kubectl get certificate api-cert -n operator-lessons -o jsonpath="{.status.$1}"; }
echo "valid for $(days "$(status notBefore)" "$(status notAfter)") days; renewed $(days "$(status notBefore)" "$(status renewalTime)") days after it was issued"

#!/usr/bin/env bash
# In mesh-lessons on donhang: have cert-manager issue, from the lab CA, a server certificate for echo-mtls and a client certificate for gateway-client (mtls-certificates.yaml), run echo-mtls (Caddy, client_auth require_and_verify), and call it without a client certificate, with one from another CA, and with gateway-client's; delete the namespace.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang from here, and openssl, here too, makes the calls through a port-forward.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster
kubectl get deployment cert-manager-webhook -n cert-manager >/dev/null 2>&1 || scripts/k8s/cert-manager-install.sh >/dev/null
[ -f secrets/lab-ca.key ] || scripts/dev-secrets.sh >/dev/null
# The client keys and the other CA live here while the script runs: under
# secrets/, which Git ignores.
work=secrets/mutual-tls
port_forward_pid=
cleanup() {
  [ -n "$port_forward_pid" ] && kill "$port_forward_pid" 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT
rm -rf "$work"
mkdir -p "$work"
kubectl delete namespace mesh-lessons --ignore-not-found --wait=true >/dev/null
kubectl create namespace mesh-lessons >/dev/null
# Right after an install, cert-manager's webhook may take a few seconds
# before the API server can reach it: try again until it answers.
apply() {
  for _ in $(seq 30); do
    kubectl apply -f "$1" 2>/dev/null && return
    sleep 2
  done
  kubectl apply -f "$1"
}

# lesson: k8s.l4.mutual-tls
# The lab CA into the Secret lab-ca; the Issuer and both Certificates.
echo "\$ kubectl create secret tls lab-ca -n mesh-lessons --cert=secrets/lab-ca.crt --key=secrets/lab-ca.key"
kubectl create secret tls lab-ca -n mesh-lessons --cert=secrets/lab-ca.crt --key=secrets/lab-ca.key
echo "\$ kubectl apply -f deploy/k8s/lessons/mtls-certificates.yaml"
apply deploy/k8s/lessons/mtls-certificates.yaml
kubectl wait --for=condition=Ready certificate --all -n mesh-lessons --timeout=120s >/dev/null
show kubectl get certificates -n mesh-lessons
echo

# lesson: k8s.l4.mutual-tls
# Both signed by the lab CA: the server's for its Service names, the
# client's with the name gateway-client, usable only by a client.
cert() { kubectl get secret "$1" -n mesh-lessons -o jsonpath='{.data.tls\.crt}' | base64 -d; }
echo "== echo-mtls-tls"
cert echo-mtls-tls | openssl x509 -noout -issuer -ext subjectAltName,extendedKeyUsage | sed '/^$/d'
echo "== gateway-client-tls"
cert gateway-client-tls | openssl x509 -noout -issuer -subject -ext extendedKeyUsage | sed '/^$/d'
echo

# lesson: k8s.l4.mutual-tls
show kubectl apply -f deploy/k8s/lessons/echo-mtls.yaml
kubectl rollout status deployment/echo-mtls -n mesh-lessons --timeout=180s >/dev/null
echo

# call_echo [openssl options]: one HTTPS request to echo-mtls with openssl,
# which checks the server's certificate against the lab CA. Each call gets
# a port-forward of its own: a refused handshake ends the one it used.
call_echo() {
  command kubectl --context kind-donhang port-forward -n mesh-lessons service/echo-mtls 28443:8443 \
    > "$work/port-forward.log" 2>&1 &
  port_forward_pid=$!
  until grep -q '^Forwarding from' "$work/port-forward.log"; do sleep 1; done
  local out
  out=$(printf 'GET / HTTP/1.1\r\nHost: echo-mtls.mesh-lessons.svc\r\nConnection: close\r\n\r\n' \
    | timeout 20 openssl s_client -connect 127.0.0.1:28443 -servername echo-mtls.mesh-lessons.svc \
        -CAfile secrets/lab-ca.crt -verify_return_error -quiet "$@" 2>&1) || true
  kill "$port_forward_pid" 2>/dev/null || true
  wait "$port_forward_pid" 2>/dev/null || true
  port_forward_pid=
  # The alert the server sent if it refused the handshake; else the
  # status line and the body of its answer.
  if grep -q 'SSL alert number' <<< "$out"; then
    echo "handshake refused: $(sed -n 's/.*:SSL routines:[a-z0-9_]*:\([^:]*\):.*/\1/p' <<< "$out" | head -n 1)"
  else
    tr -d '\r' <<< "$out" | grep -m 1 '^HTTP/'
    echo "$(tr -d '\r' <<< "$out" | sed '1,/^$/d')"
  fi
}

# lesson: k8s.l4.mutual-tls
# No client certificate: the server asks for one, gets none and ends the
# handshake before any request.
echo "\$ openssl s_client -connect echo-mtls (port-forward) -CAfile secrets/lab-ca.crt"
call_echo
echo

# lesson: k8s.l4.mutual-tls
# A certificate for the same name, gateway-client, but from a CA made just
# now: the server does not trust that CA, and ends the handshake.
openssl req -x509 -newkey rsa:2048 -nodes -subj /CN=other-ca -days 1 \
  -keyout "$work/other-ca.key" -out "$work/other-ca.crt" 2>/dev/null
openssl req -newkey rsa:2048 -nodes -subj /CN=gateway-client \
  -keyout "$work/other-client.key" -out "$work/other-client.csr" 2>/dev/null
printf 'extendedKeyUsage=clientAuth\n' > "$work/client.ext"
openssl x509 -req -in "$work/other-client.csr" -CA "$work/other-ca.crt" -CAkey "$work/other-ca.key" \
  -CAcreateserial -days 1 -extfile "$work/client.ext" -out "$work/other-client.crt" 2>/dev/null
echo "\$ openssl s_client -connect echo-mtls (port-forward) -CAfile secrets/lab-ca.crt -cert <gateway-client, signed by another CA> -key ..."
call_echo -cert "$work/other-client.crt" -key "$work/other-client.key"
echo

# lesson: k8s.l4.mutual-tls
# gateway-client's certificate and key, from the Secret cert-manager wrote:
# the handshake succeeds, and echo-mtls answers with the name in it.
cert gateway-client-tls > "$work/gateway-client.crt"
kubectl get secret gateway-client-tls -n mesh-lessons -o jsonpath='{.data.tls\.key}' | base64 -d > "$work/gateway-client.key"
echo "\$ openssl s_client -connect echo-mtls (port-forward) -CAfile secrets/lab-ca.crt -cert <gateway-client-tls's tls.crt> -key <its tls.key>"
call_echo -cert "$work/gateway-client.crt" -key "$work/gateway-client.key"

kubectl delete namespace mesh-lessons --wait=false >/dev/null

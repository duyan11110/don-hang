#!/usr/bin/env bash
# In mesh-lessons on donhang: run echo-sidecar (echo app on localhost, Caddy sidecar with mTLS on 8443) and caller (app plus a Caddy sidecar holding gateway-client's certificate); show each Pod's containers, a call from the caller's app to its sidecar that echo answers, a direct call to 8443 without a certificate refused, and that neither app container holds a key; delete the namespace.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster
kubectl get deployment cert-manager-webhook -n cert-manager >/dev/null 2>&1 || scripts/k8s/cert-manager-install.sh >/dev/null
[ -f secrets/lab-ca.key ] || scripts/dev-secrets.sh >/dev/null
kubectl delete namespace mesh-lessons --ignore-not-found --wait=true >/dev/null
kubectl create namespace mesh-lessons >/dev/null
# The certificates of k8s.l4.mutual-tls (scripts/k8s/mutual-tls.sh shows
# them): the server's for echo-sidecar, gateway-client's for the caller.
kubectl create secret tls lab-ca -n mesh-lessons --cert=secrets/lab-ca.crt --key=secrets/lab-ca.key >/dev/null
for _ in $(seq 30); do
  kubectl apply -f deploy/k8s/lessons/mtls-certificates.yaml >/dev/null 2>&1 && break
  sleep 2
done
kubectl wait --for=condition=Ready certificate --all -n mesh-lessons --timeout=120s >/dev/null

# lesson: k8s.l4.sidecar-proxies
# Two Pods of two containers each: READY 2/2 counts the sidecar too.
show kubectl apply -f deploy/k8s/lessons/echo-mtls-sidecar.yaml
show kubectl apply -f deploy/k8s/lessons/mtls-client-sidecar.yaml
kubectl rollout status deployment/echo-sidecar -n mesh-lessons --timeout=180s >/dev/null
kubectl rollout status deployment/caller -n mesh-lessons --timeout=180s >/dev/null
show kubectl get pods -n mesh-lessons
echo

# lesson: k8s.l4.sidecar-proxies
# The sidecar is listed under initContainers, with restartPolicy Always;
# the app is the one container under containers.
for app in echo-sidecar caller; do
  echo "\$ kubectl get pod -l app=$app -n mesh-lessons -o jsonpath=<init containers, containers>"
  kubectl get pod -l "app=$app" -n mesh-lessons -o jsonpath='{range .items[0].spec.initContainers[*]}initContainers: {.name} (restartPolicy: {.restartPolicy}){"\n"}{end}{range .items[0].spec.containers[*]}containers: {.name}{"\n"}{end}'
done
echo

# lesson: k8s.l4.sidecar-proxies
# The caller's app sends plain HTTP to its own sidecar on localhost; the
# sidecars do the mTLS between them, and the echo app learns the caller's
# name from the header its sidecar adds.
show kubectl exec deploy/caller -n mesh-lessons -c app -- wget -qO- http://127.0.0.1:9000/
echo
echo

# lesson: k8s.l4.sidecar-proxies
# Past its sidecar, straight to echo-sidecar's port 8443 without a client
# certificate: the server's sidecar refuses the handshake, and no response
# comes back.
echo "\$ kubectl exec deploy/caller -n mesh-lessons -c app -- wget --no-check-certificate -qO- https://echo-sidecar.mesh-lessons.svc:8443/"
if kubectl exec deploy/caller -n mesh-lessons -c app -- \
     wget --no-check-certificate -qO- https://echo-sidecar.mesh-lessons.svc:8443/ 2>&1 | grep -v '^command terminated'; then :; fi
echo

# lesson: k8s.l4.sidecar-proxies
# The keys are only in the sidecars: neither app container has /certs.
for target in "deploy/echo-sidecar -c echo" "deploy/echo-sidecar -c tls-proxy" \
              "deploy/caller -c app" "deploy/caller -c tls-proxy"; do
  read -r workload flag container <<< "$target"
  echo "\$ kubectl exec $workload -n mesh-lessons $flag $container -- ls /certs"
  kubectl exec "$workload" -n mesh-lessons "$flag" "$container" -- ls /certs 2>&1 | grep -v '^command terminated' || true
done

kubectl delete namespace mesh-lessons --wait=false >/dev/null

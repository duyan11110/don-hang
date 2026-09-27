#!/usr/bin/env bash
# Run a Caddy Pod whose liveness probe always gets 404 and watch the kubelet restart its container in the same Pod; then show the api's probes.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the kind cluster from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
show() { echo "\$ $*"; "$@"; }
pod_field() { kubectl get pod web-liveness -n donhang -o jsonpath="$1"; }

kubectl apply -f deploy/k8s/namespace.yaml >/dev/null
kubectl delete -f deploy/k8s/lessons/web-liveness-pod.yaml --ignore-not-found >/dev/null

# lesson: k8s.l1.liveness-probes
show kubectl apply -f deploy/k8s/lessons/web-liveness-pod.yaml
kubectl wait --for=condition=Ready pod/web-liveness -n donhang --timeout=120s >/dev/null
uid=$(pod_field '{.metadata.uid}')
ip=$(pod_field '{.status.podIP}')
# Every 10 s the kubelet asks for /healthz; after 3 failures in a row it
# kills the container and starts it again, in the same Pod.
for _ in $(seq 120); do
  [ "$(pod_field '{.status.containerStatuses[0].restartCount}')" -ge 1 ] && break
  sleep 1
done
show kubectl get pod web-liveness -n donhang
echo "Still the same Pod (same uid): $([ "$(pod_field '{.metadata.uid}')" = "$uid" ] && echo yes || echo no)"
echo "Still the same IP address: $([ "$(pod_field '{.status.podIP}')" = "$ip" ] && echo yes || echo no)"
echo
# It keeps failing, so the kubelet waits longer and longer before each new
# start; while it waits, the Pod's status is CrashLoopBackOff.
for _ in $(seq 300); do
  [ "$(pod_field '{.status.containerStatuses[0].state.waiting.reason}')" = CrashLoopBackOff ] && break
  sleep 1
done
echo "\$ kubectl get pod web-liveness -n donhang -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}'"
pod_field '{.status.containerStatuses[0].state.waiting.reason}'
echo
echo
echo "== the Pod's events about the probe, each one once"
kubectl get events -n donhang --field-selector involvedObject.name=web-liveness \
  -o jsonpath='{range .items[*]}{.reason}: {.message}{"\n"}{end}' | grep -E '^(Unhealthy|Killing):' | sort -u
kubectl delete -f deploy/k8s/lessons/web-liveness-pod.yaml >/dev/null
echo

# The api's probes as describe sums them up, with the defaults filled in.
if kubectl get deployment api -n donhang >/dev/null 2>&1; then
  echo "\$ kubectl describe deployment api -n donhang | grep -E 'Liveness|Readiness'"
  kubectl describe deployment api -n donhang | grep -E 'Liveness|Readiness' | sed 's/^ *//'
fi

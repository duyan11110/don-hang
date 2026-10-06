#!/usr/bin/env bash
# Install Traefik on donhang (namespace ha-lessons) from the chart version staging pins, with two spread replicas behind a MetalLB address; route echo-ip through it; pause one worker while calling the address in a loop.
# Runs on the host, like every script in scripts/k8s/: helm, kubectl and docker talk to the cluster donhang and its node containers from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
helm() { command helm --kube-context kind-donhang "$@"; }
lessons_cluster
echo_ip_up
metallb_up
paused=
trap 'if [ -n "$paused" ]; then docker unpause "$paused" >/dev/null; fi' EXIT

# lesson: k8s.l3.highly-available-entry-point
# The chart and version of apps/traefik.yaml, with the values of
# traefik-ha-values.yaml: two replicas, spread over the two workers.
echo "\$ helm upgrade --install traefik-ha traefik --repo https://traefik.github.io/charts --version 41.6.1 \\"
echo "    -n ha-lessons --create-namespace -f deploy/k8s/lessons/traefik-ha-values.yaml --wait"
helm upgrade --install traefik-ha traefik --repo https://traefik.github.io/charts --version 41.6.1 \
  -n ha-lessons --create-namespace -f deploy/k8s/lessons/traefik-ha-values.yaml --wait --timeout 300s \
  | grep -E '^(NAME|STATUS|REVISION):'
show kubectl get pods -n ha-lessons -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName
for _ in $(seq 60); do [ -n "$(kubectl get service traefik-ha -n ha-lessons -o jsonpath='{.status.loadBalancer.ingress[0].ip}')" ] && break; sleep 1; done
show kubectl get service traefik-ha -n ha-lessons
ip=$(kubectl get service traefik-ha -n ha-lessons -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo

show kubectl apply -f deploy/k8s/lessons/echo-ingress.yaml
for _ in $(seq 30); do lb_get "$ip" 2 >/dev/null && break; sleep 1; done
echo "\$ docker exec donhang-lb-client wget -qO- http://<traefik-ha's address>"
lb_get "$ip"
echo

# lesson: k8s.l3.highly-available-entry-point
# One worker stops: the one that announces the address, so it has to move.
# A call every second: some fail, until MetalLB has moved the address and
# the control plane has marked the stopped node's Pods not ready (its
# Traefik and its echo-ip), then every call succeeds again.
node=$(lb_node_ip "$ip")
echo "\$ docker pause $node"
docker pause "$node" >/dev/null
paused=$node
start=$SECONDS ok=0 failed=0 streak=0
while [ "$streak" -lt 20 ]; do
  if lb_get "$ip" 2 >/dev/null; then ok=$((ok + 1)); streak=$((streak + 1)); else failed=$((failed + 1)); streak=0; last_fail=$((SECONDS - start)); fi
  [ $((SECONDS - start)) -gt 300 ] && { echo "calls still failing after 300 s" >&2; exit 1; }
  sleep 1
done
echo "calls: $((ok + failed)), failed: $failed, the last one about ${last_fail:-0} s after the pause; then 20 in a row succeeded"
show kubectl get node "$node" -o custom-columns=NODE:.metadata.name,READY:.status.conditions[-1].status
echo "the address is announced by $(lb_node_ip "$ip")"

echo "\$ docker unpause $node"
docker unpause "$node" >/dev/null
paused=
kubectl wait --for=condition=Ready "node/$node" --timeout=180s >/dev/null

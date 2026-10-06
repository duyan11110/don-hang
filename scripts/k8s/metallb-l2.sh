#!/usr/bin/env bash
# Show which node announces echo-loadbalancer's address and the hardware (MAC) address a client learned for it, then pause that node's container and watch another node take the address over.
# Runs on the host, like every script in scripts/k8s/: kubectl and docker talk to the cluster donhang and its node containers from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster
echo_ip_up
metallb_up
kubectl apply -f deploy/k8s/lessons/echo-loadbalancer.yaml >/dev/null
lb=$(lb_ip echo-loadbalancer)
# However the script ends, the paused node runs again.
paused=
trap 'if [ -n "$paused" ]; then docker unpause "$paused" >/dev/null; fi' EXIT

# lesson: k8s.l3.metallb-layer2-mode
# One node's speaker answers ARP for the address: MetalLB records which in
# a ServiceL2Status. The client asked "who has this address?" and learned
# that node's hardware address; the address itself is on no network card.
lb_get "$lb" >/dev/null
node=$(lb_node echo-loadbalancer)
echo "echo-loadbalancer: $lb, announced by $node"
show kubectl get servicel2statuses -n metallb-system -o custom-columns=SERVICE:.status.serviceName,NODE:.status.node
echo "MAC of $node: $(mac_of "$node")"
echo "the client's ARP entry for $lb: $(arp_of "$lb")"
echo

# lesson: k8s.l3.metallb-layer2-mode
# The announcing node stops: its container is paused. The client keeps
# calling, once a second, until its ARP entry names another node: the other
# speakers noticed and one of them announced the address from its node.
old_mac=$(arp_of "$lb")
echo "\$ docker pause $node"
docker pause "$node" >/dev/null
paused=$node
start=$SECONDS
calls=0 failed=0
while [ "$(arp_of "$lb")" = "$old_mac" ]; do
  calls=$((calls + 1))
  lb_get "$lb" 1 >/dev/null || failed=$((failed + 1))
  [ $((SECONDS - start)) -gt 120 ] && { echo "the address did not move in 120 s" >&2; exit 1; }
  sleep 1
done
new_mac=$(arp_of "$lb")
new=$(lb_node echo-loadbalancer)
echo "after about $((SECONDS - start)) s and $calls calls ($failed failed): the client's ARP entry for $lb is $new_mac, the MAC of $new"
echo

echo "\$ docker unpause $node"
docker unpause "$node" >/dev/null
paused=
kubectl wait --for=condition=Ready "node/$node" --timeout=180s >/dev/null

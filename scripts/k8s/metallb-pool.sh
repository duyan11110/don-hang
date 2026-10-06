#!/usr/bin/env bash
# Fill metallb-pool.yaml with a range from the subnet of Docker's kind network, apply it, watch echo-loadbalancer get an EXTERNAL-IP, and call that address from a container on the kind network.
# Runs on the host, like every script in scripts/k8s/: kubectl and docker talk to the cluster donhang and its Docker network from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster
echo_ip_up
kubectl get namespace metallb-system >/dev/null 2>&1 || scripts/k8s/metallb-install.sh >/dev/null

# lesson: k8s.l3.metallb-address-pools
# The IPv4 subnet Docker gave the network kind on this machine: x.y of the
# pool are its first two numbers.
subnet=$(docker network inspect kind -f '{{range .IPAM.Config}}{{println .Subnet}}{{end}}' | grep -m1 '^[0-9.]*/16$')
echo "the network kind: $subnet"
prefix=$(echo "$subnet" | cut -d. -f1-2)
echo "\$ sed 's/x\.y\./$prefix./g' deploy/k8s/lessons/metallb-pool.yaml | kubectl apply -f -"
sed "s/x\.y\./$prefix./g" deploy/k8s/lessons/metallb-pool.yaml | kubectl apply -f -
show kubectl get ipaddresspools -n metallb-system
echo

# lesson: k8s.l3.metallb-address-pools
# echo-loadbalancer gets an address from the pool, and keeps its cluster
# IP and node port.
kubectl apply -f deploy/k8s/lessons/echo-loadbalancer.yaml >/dev/null
for _ in $(seq 60); do
  [ -n "$(kubectl get service echo-loadbalancer -n network-lessons -o jsonpath='{.status.loadBalancer.ingress[0].ip}')" ] && break
  sleep 1
done
show kubectl get service echo-loadbalancer -n network-lessons
lb_ip=$(kubectl get service echo-loadbalancer -n network-lessons -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo

# lesson: k8s.l3.metallb-address-pools
# Docker Desktop does not route this machine to the network kind, so the
# call comes from a container attached to it, as any machine on a real
# network could call.
docker rm -f donhang-lb-client >/dev/null 2>&1 || true
echo "\$ docker run -d --name donhang-lb-client --network kind caddy:2.10.0 sleep infinity"
docker run -d --name donhang-lb-client --network kind caddy:2.10.0 sleep infinity >/dev/null
echo "\$ docker exec donhang-lb-client wget -qO- http://$lb_ip"
docker exec donhang-lb-client wget -T 5 -qO- "http://$lb_ip"

# Sourced by the scripts of k8s/networking-deep, bare-metal and
# operators-and-cluster-lifecycle that run on the cluster donhang.
# Every kubectl here talks to donhang, whatever context is current.
kubectl() { command kubectl --context kind-donhang "$@"; }
show() { echo "\$ $*"; "$@"; }
# Paths like /etc/resolv.conf are paths inside a container: Git Bash must not
# turn them into Windows paths.
export MSYS_NO_PATHCONV=1

# The lessons of state-and-storage may have ended with cluster-down.sh:
# build donhang again (one control-plane node, two workers) if it is gone.
lessons_cluster() {
  if ! kind get clusters 2>/dev/null | grep -qx donhang; then
    scripts/k8s/cluster-up.sh >/dev/null
  fi
}

# echo-ip in network-lessons, both Pods ready.
echo_ip_up() {
  kubectl apply -f deploy/k8s/lessons/echo-ip.yaml >/dev/null
  kubectl rollout status deployment/echo-ip -n network-lessons --timeout=180s >/dev/null
}

# A client Pod (Caddy's image has wget, nc and getent) in network-lessons,
# on the given node or wherever the scheduler puts it.
client_up() {
  local name=$1 node=${2:-}
  kubectl delete pod "$name" -n network-lessons --ignore-not-found --grace-period=1 >/dev/null
  if [ -n "$node" ]; then
    kubectl run "$name" -n network-lessons --image=caddy:2.10.0 \
      --overrides="{\"spec\":{\"nodeName\":\"$node\"}}" --command -- sleep 3600 >/dev/null
  else
    kubectl run "$name" -n network-lessons --image=caddy:2.10.0 --command -- sleep 3600 >/dev/null
  fi
  kubectl wait --for=condition=Ready "pod/$name" -n network-lessons --timeout=180s >/dev/null
}

# The address MetalLB gave a Service in network-lessons, and a call to it
# from donhang-lb-client, a container on Docker's network kind
# (scripts/k8s/metallb-pool.sh starts it).
lb_ip() { kubectl get service "$1" -n network-lessons -o jsonpath='{.status.loadBalancer.ingress[0].ip}'; }
lb_get() { docker exec donhang-lb-client wget -T "${2:-5}" -qO- "http://$1" 2>/dev/null; }
# The node whose speaker announces an address (layer 2 mode), as the client
# container sees it: the node whose MAC its ARP table holds for the address.
mac_of() { docker inspect -f '{{(index .NetworkSettings.Networks "kind").MacAddress}}' "$1"; }
arp_of() { docker exec donhang-lb-client cat /proc/net/arp | awk -v ip="$1" '$1 == ip { print $4 }'; }
lb_node() { lb_node_ip "$(lb_ip "$1")"; }
lb_node_ip() {
  local ip=$1 mac node
  lb_get "$ip" 2 >/dev/null || true
  mac=$(arp_of "$ip")
  for node in $(kind get nodes --name donhang); do
    if [ "$(mac_of "$node")" = "$mac" ]; then echo "$node"; fi
  done
}
# MetalLB with its pool, and the client container, if an earlier script of
# k8s/bare-metal has not set them up yet.
metallb_up() {
  if ! kubectl get ipaddresspool lab-pool -n metallb-system >/dev/null 2>&1 \
     || ! docker inspect donhang-lb-client >/dev/null 2>&1; then
    scripts/k8s/metallb-pool.sh >/dev/null
  fi
}

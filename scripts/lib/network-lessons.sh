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

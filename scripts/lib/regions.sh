# Sourced by the scripts of k8s/multi-cluster-and-mesh that work with the
# two one-node clusters standing in for two regions, donhang-north and
# donhang-south. Both contexts sit in one kubeconfig in secrets/, which Git
# ignores (it holds each cluster's admin key); ~/.kube/config is left alone.
regions=(north south)
regions_config=secrets/regions.kubeconfig
show() { echo "\$ $*"; "$@"; }
# region <north|south> <kubectl arguments>: kubectl on that region's cluster.
region() {
  local name=$1
  shift
  command kubectl --kubeconfig "$regions_config" --context "kind-donhang-$name" "$@"
}
# The node image of deploy/k8s/kind-config.yaml, pinned by its digest.
node_image() { sed -n 's/^ *image: *//p' deploy/k8s/kind-config.yaml | head -n 1; }
# Both clusters, created by scripts/k8s/regions-up.sh if one is missing.
regions_up() {
  local name
  for name in "${regions[@]}"; do
    if ! kind get clusters 2>/dev/null | grep -qx "donhang-$name" \
       || ! region "$name" get nodes >/dev/null 2>&1; then
      scripts/k8s/regions-up.sh >/dev/null
      return
    fi
  done
}
# The answer of echo-region on a region's node port, from inside its node
# (the node image has curl).
region_echo() { docker exec "donhang-$1-control-plane" curl -s -m 5 http://localhost:30090/; }

# Sourced by scripts/k8s/etcd-snapshot.sh and encryption-at-rest.sh, which
# work on the throwaway cluster donhang-lifecycle (deploy/k8s/kind-lifecycle-config.yaml).
# Its kubeconfig holds its admin's key: it goes to secrets/, which Git
# ignores, and kind leaves ~/.kube/config alone.
lc_config=secrets/donhang-lifecycle.kubeconfig
lc_node=donhang-lifecycle-control-plane
kubectl() { command kubectl --kubeconfig "$lc_config" "$@"; }
show() { echo "\$ $*"; "$@"; }
# Paths like /var/lib/etcd are paths inside the node or a container.
export MSYS_NO_PATHCONV=1

# lifecycle_cluster [--new]: donhang-lifecycle, created if missing (or
# created again with --new), its node Ready.
lifecycle_cluster() {
  if [ "${1:-}" = --new ] || ! kind get clusters 2>/dev/null | grep -qx donhang-lifecycle \
     || [ ! -f "$lc_config" ]; then
    kind delete cluster --name donhang-lifecycle >/dev/null 2>&1 || true
    kind create cluster --name donhang-lifecycle --config deploy/k8s/kind-lifecycle-config.yaml \
      --kubeconfig "$lc_config" --wait 300s >/dev/null 2>&1
  fi
  kubectl wait --for=condition=Ready node --all --timeout=300s >/dev/null
}
lifecycle_delete() {
  kind delete cluster --name donhang-lifecycle --kubeconfig "$lc_config" 2>&1 | grep -v '^Deleted nodes'
  rm -f "$lc_config"
}

# etcdctl and etcdutl run inside etcd's own Pod (its image has no shell):
# etcdctl talks to etcd's client port with the certificates kubeadm made.
etcd_pod="etcd-$lc_node"
etcd_tls=(--endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt
          --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key)
etcdctl() { kubectl exec -n kube-system "$etcd_pod" -- etcdctl "${etcd_tls[@]}" "$@"; }
etcdutl() { kubectl exec -n kube-system "$etcd_pod" -- etcdutl "$@"; }

# Wait until the API server answers again, after its static Pod restarted.
api_wait() {
  for _ in $(seq 180); do
    kubectl get --raw /readyz >/dev/null 2>&1 && return 0
    sleep 2
  done
  echo "the API server of donhang-lifecycle did not come back" >&2
  return 1
}

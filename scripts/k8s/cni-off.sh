#!/usr/bin/env bash
# Create donhang-nocni, a kind cluster without a network plugin: its nodes stay NotReady, CoreDNS stays Pending and the worker has no route to another node's Pod range; then delete it.
# Runs on the host, like every script in scripts/k8s/: kind, kubectl and docker create, read and delete its node containers from here. donhang-nocni needs about 2 GB more of Docker's memory while it runs.
set -euo pipefail
cd "$(dirname "$0")/../.."
# donhang-nocni's kubeconfig holds its admin's key: it goes to secrets/,
# which Git ignores, and kind leaves ~/.kube/config alone.
config=secrets/donhang-nocni.kubeconfig
nocni() { command kubectl --kubeconfig "$config" --request-timeout=15s "$@"; }
cleanup() {
  if kind get clusters 2>/dev/null | grep -qx donhang-nocni; then
    kind delete cluster --name donhang-nocni --kubeconfig "$config" >/dev/null 2>&1
  fi
  rm -f "$config"
}
trap cleanup EXIT

# lesson: k8s.l3.cni-plugins
# The same kind of cluster as donhang, built without kindnet. A minute is
# far longer than donhang's nodes take to become Ready; these never do.
echo "\$ kind create cluster --name donhang-nocni --config deploy/k8s/kind-no-cni-config.yaml --kubeconfig $config"
kind create cluster --name donhang-nocni --config deploy/k8s/kind-no-cni-config.yaml --kubeconfig "$config" >/dev/null 2>&1
sleep 60
echo "\$ kubectl --kubeconfig $config get nodes"
nocni get nodes
echo "why donhang-nocni-worker is not Ready: $(nocni get node donhang-nocni-worker -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}')"
echo "\$ kubectl --kubeconfig $config get pods -n kube-system -l k8s-app=kube-dns"
nocni get pods -n kube-system -l k8s-app=kube-dns -o custom-columns=POD:.metadata.name,STATUS:.status.phase,IP:.status.podIP
echo
# lesson: k8s.l3.cni-plugins
# kindnet is what writes the Pod routes: with no plugin, the worker has only
# its default route, and no line for the control-plane node's Pod range.
echo "\$ docker exec donhang-nocni-worker ip route | grep via"
docker exec donhang-nocni-worker ip route | grep via
echo

echo "\$ kind delete cluster --name donhang-nocni"
kind delete cluster --name donhang-nocni --kubeconfig "$config" 2>&1 | grep -v '^Deleted nodes'

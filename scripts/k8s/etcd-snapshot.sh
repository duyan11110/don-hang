#!/usr/bin/env bash
# Create the one-node cluster donhang-lifecycle, create the ConfigMap before, take an etcd snapshot and copy it off the node, create the ConfigMap after, then restore the snapshot: before is back, after is gone.
# Runs on the host, like every script in scripts/k8s/: kind, kubectl and docker create the cluster and work on its node container from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/lifecycle.sh

echo "\$ kind create cluster --name donhang-lifecycle --config deploy/k8s/kind-lifecycle-config.yaml --kubeconfig $lc_config"
lifecycle_cluster --new
show kubectl get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion
echo

# lesson: k8s.l3.etcd-snapshots
# A ConfigMap that exists when the snapshot is taken.
show kubectl create configmap before --from-literal=taken=before-the-snapshot
# etcdctl, inside etcd's Pod, through the client port with the
# certificates kubeadm created: the whole store, written to a file in
# /var/lib/etcd, which the Pod mounts from the node.
echo "\$ kubectl exec -n kube-system $etcd_pod -- etcdctl --endpoints=https://127.0.0.1:2379 \\"
echo "    --cacert=... --cert=... --key=... snapshot save /var/lib/etcd/snapshot.db"
etcdctl snapshot save /var/lib/etcd/snapshot.db 2>&1 | grep -o 'Snapshot saved at .*'
# Off the node: a snapshot that stays on the node is lost with the node.
mkdir -p backups/etcd
echo "\$ docker cp $lc_node:/var/lib/etcd/snapshot.db backups/etcd/donhang-lifecycle.db"
docker cp "$lc_node:/var/lib/etcd/snapshot.db" backups/etcd/donhang-lifecycle.db 2>/dev/null
echo "copied: $(ls backups/etcd/donhang-lifecycle.db)"
# A ConfigMap created after the snapshot.
show kubectl create configmap after --from-literal=taken=after-the-snapshot
show kubectl get configmaps before after
echo

# lesson: k8s.l3.etcd-snapshots
# etcdutl writes a new data folder from the snapshot, for a member with the
# name and peer address etcd's static Pod uses. The running etcd does not
# see it yet.
ip=$(kubectl get node "$lc_node" -o jsonpath='{.status.addresses[0].address}')
echo "\$ kubectl exec -n kube-system $etcd_pod -- etcdutl snapshot restore /var/lib/etcd/snapshot.db \\"
echo "    --data-dir /var/lib/etcd/restored --name $lc_node --initial-cluster $lc_node=https://<node address>:2380 ..."
etcdutl snapshot restore /var/lib/etcd/snapshot.db --data-dir /var/lib/etcd/restored --name "$lc_node" \
  --initial-cluster "$lc_node=https://$ip:2380" --initial-advertise-peer-urls "https://$ip:2380" >/dev/null 2>&1
echo

# lesson: k8s.l3.etcd-snapshots
# Swap the data: the static Pods of etcd and the API server leave the
# manifests folder, so the kubelet stops them; the restored member folder
# takes the old one's place; the manifests come back, and the kubelet
# starts both again on the restored data.
node() { echo "\$ docker exec $lc_node sh -c '$*'"; docker exec "$lc_node" sh -c "$*"; }
node 'mkdir -p /root/stopped && mv /etc/kubernetes/manifests/etcd.yaml /etc/kubernetes/manifests/kube-apiserver.yaml /root/stopped/'
until [ -z "$(docker exec "$lc_node" crictl ps -q --name '^(etcd|kube-apiserver)$')" ]; do sleep 2; done
node 'mv /var/lib/etcd/member /var/lib/etcd/member.before-restore && mv /var/lib/etcd/restored/member /var/lib/etcd/member'
node 'mv /root/stopped/etcd.yaml /root/stopped/kube-apiserver.yaml /etc/kubernetes/manifests/'
api_wait
echo

# lesson: k8s.l3.etcd-snapshots
# The cluster is back at the moment of the snapshot: before exists, after
# was never written.
echo "\$ kubectl get configmaps before after"
kubectl get configmaps before after 2>&1 || true

#!/usr/bin/env bash
# On donhang-lifecycle: read a Secret straight from etcd (readable), give the API server an EncryptionConfiguration with secretbox (scripts/dev-secrets.sh), write Secrets again, read etcd again (encrypted); then delete donhang-lifecycle.
# Runs on the host, like every script in scripts/k8s/: kind, kubectl and docker work on donhang-lifecycle and its node container from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/lifecycle.sh
scripts/dev-secrets.sh >/dev/null
lifecycle_cluster
kubectl delete secret lab-before lab-after --ignore-not-found >/dev/null
# etcd_read <secret>: what etcd holds for the Secret in default, shown as
# text: its key, the start of the stored value, and whether the Secret's
# value appears in it as written.
etcd_read() {
  local raw
  raw=$(etcdctl get "/registry/secrets/default/$1" | tr -c '[:print:]\n' '.')
  echo "\$ kubectl exec -n kube-system $etcd_pod -- etcdctl ... get /registry/secrets/default/$1"
  echo "$raw" | head -n 1
  echo "$raw" | sed -n 2p | cut -c1-26
  if echo "$raw" | grep -q "$2"; then echo "  ($2 is readable in it)"; else echo "  ($2 is not in it as written)"; fi
}

# lesson: k8s.l3.encryption-at-rest
# By default the API server stores a Secret's value as it is: read from
# etcd directly, it starts with k8s and the value is there to read.
show kubectl create secret generic lab-before --from-literal=password=written-before
etcd_read lab-before written-before
echo

# lesson: k8s.l3.encryption-at-rest
# The EncryptionConfiguration goes to the node, and the API server's
# static Pod gets the flag that names it and a volume to read it from.
echo "\$ docker cp secrets/encryption-config.yaml $lc_node:/etc/kubernetes/enc/encryption-config.yaml"
docker exec "$lc_node" mkdir -p /etc/kubernetes/enc
docker cp secrets/encryption-config.yaml "$lc_node:/etc/kubernetes/enc/encryption-config.yaml" 2>/dev/null
manifest=/etc/kubernetes/manifests/kube-apiserver.yaml
docker exec "$lc_node" sh -c "sed \
  -e 's#^    - kube-apiserver\$#&\n    - --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml#' \
  -e 's#^    volumeMounts:\$#&\n    - mountPath: /etc/kubernetes/enc\n      name: enc\n      readOnly: true#' \
  -e 's#^  volumes:\$#&\n  - hostPath:\n      path: /etc/kubernetes/enc\n      type: DirectoryOrCreate\n    name: enc#' \
  $manifest > /root/kube-apiserver.yaml && mv /root/kube-apiserver.yaml $manifest"
echo "\$ docker exec $lc_node grep -e encryption-provider-config -e 'path: /etc/kubernetes/enc' $manifest"
docker exec "$lc_node" grep -e encryption-provider-config -e 'path: /etc/kubernetes/enc' "$manifest"
# The kubelet restarts the API server with the new flag.
until kubectl get pod "kube-apiserver-$lc_node" -n kube-system -o jsonpath='{.spec.containers[0].command}' 2>/dev/null \
    | grep -q encryption-provider-config; do sleep 2; done
api_wait
echo

# lesson: k8s.l3.encryption-at-rest
# A Secret written now is stored encrypted: the value in etcd starts with
# k8s:enc:secretbox:v1:key1:. The one written before is still readable.
show kubectl create secret generic lab-after --from-literal=password=written-after
etcd_read lab-after written-after
etcd_read lab-before written-before
echo

# lesson: k8s.l3.encryption-at-rest
# Rewriting every Secret through the API server stores each one again,
# encrypted this time.
echo "\$ kubectl get secrets -A -o json | kubectl replace -f -"
echo "Secrets replaced: $(kubectl get secrets -A -o json | kubectl replace -f - | grep -c ' replaced$')"
etcd_read lab-before written-before
echo

# lesson: k8s.l3.encryption-at-rest
# Through the API server nothing changed: anyone RBAC allows still reads
# the value.
echo "\$ kubectl get secret lab-before -o jsonpath='{.data.password}' | base64 -d"
kubectl get secret lab-before -o jsonpath='{.data.password}' | base64 -d
echo
echo

echo "\$ kind delete cluster --name donhang-lifecycle"
lifecycle_delete

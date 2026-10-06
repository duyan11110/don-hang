#!/usr/bin/env bash
# Commit RabbitMQ as a StatefulSet with a headless Service (base/rabbitmq.yaml), resolve its names from an api Pod, then delete rabbitmq-0: same DNS name, new address, same queues.
# Runs on the host, like every script in scripts/k8s/: kubectl and git talk to donhang-staging and its Git server from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/gitops.sh
show() { echo "\$ $*"; "$@"; }
pod_dns=rabbitmq-0.rabbitmq-headless.donhang.svc.cluster.local
# getent from an api Pod: the C library's own lookup, as the api's would be.
resolve() { kubectl exec deployment/api -n donhang -- getent ahostsv4 "$1" | awk '{ print $1 }' | sort -u; }
pod_ip() { kubectl get pod rabbitmq-0 -n donhang -o jsonpath='{.status.podIP}'; }
queues() { kubectl exec rabbitmq-0 -n donhang -- rabbitmqctl list_queues --quiet name durable | sort; }

if [ ! -f "$config_repo/envs/staging/kustomization.yaml" ]; then
  echo "envs/staging is not a Kustomize overlay yet: run scripts/k8s/kustomize-config-repo.sh first" >&2
  exit 1
fi

# RabbitMQ joins staging: the StatefulSet, its two Services and its claim.
config_take base/rabbitmq.yaml
if [ -n "$(git -C "$config_repo" status --porcelain)" ]; then
  config_commit headless-dns.sh "RabbitMQ: a StatefulSet with a claim, the Services rabbitmq and rabbitmq-headless"
fi
app_refresh
app_wait_sync "$(config_head --verify)" >/dev/null
app_wait Synced Healthy "$(config_head --verify)"
kubectl wait --for=condition=Ready pod/rabbitmq-0 -n donhang --timeout=300s >/dev/null
# The api declares its queue when it starts: new api Pods find RabbitMQ.
kubectl delete pods -n donhang -l app=api --wait=false >/dev/null
kubectl rollout status deployment/api -n donhang --timeout=300s >/dev/null
echo "\$ kubectl get services -n donhang"
kubectl get services -n donhang -o custom-columns=NAME:.metadata.name,CLUSTER-IP:.spec.clusterIP | grep -e NAME -e rabbitmq
echo

# lesson: k8s.l2.headless-services
# rabbitmq resolves to the Service's virtual address; rabbitmq-headless,
# which has none, to the address of the ready Pod itself; and the Pod has
# a name of its own under it.
ip=$(pod_ip)
echo "rabbitmq           -> the Service's address: $([ "$(resolve rabbitmq)" = "$(kubectl get service rabbitmq -n donhang -o jsonpath='{.spec.clusterIP}')" ] && echo yes || echo no)"
echo "rabbitmq-headless  -> rabbitmq-0's address: $([ "$(resolve rabbitmq-headless)" = "$ip" ] && echo yes || echo no)"
echo "$pod_dns -> rabbitmq-0's address: $([ "$(resolve "$pod_dns")" = "$ip" ] && echo yes || echo no)"
echo "== queues on rabbitmq-0"
queues
echo

# lesson: k8s.l2.headless-services
# The replacement rabbitmq-0 gets a new address under the same DNS name,
# so the node name built from it is the same, and so is the folder its
# queues live in on the claim.
show kubectl delete pod rabbitmq-0 -n donhang
kubectl wait --for=condition=Ready pod/rabbitmq-0 -n donhang --timeout=300s >/dev/null
echo "rabbitmq-0's address changed: $([ "$(pod_ip)" != "$ip" ] && echo yes || echo no)"
echo "$pod_dns -> the new address: $([ "$(resolve "$pod_dns")" = "$(pod_ip)" ] && echo yes || echo no)"
echo "== the node's name and its folder on the claim"
kubectl exec rabbitmq-0 -n donhang -- rabbitmqctl eval 'node().' --quiet
kubectl exec rabbitmq-0 -n donhang -- ls /var/lib/rabbitmq/mnesia | grep -v -e '\.pid$' -e 'plugins-expand$' -e 'feature_flags$'
echo "== queues on the new rabbitmq-0"
queues

#!/usr/bin/env bash
# Break echo-ip three ways (broken-echo.yaml: a selector typo, a wrong targetPort, an egress policy without DNS) and find each one: the error, the EndpointSlice, the Pod's own address, then kubectl debug inside the failing Pod.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster
echo_ip_up
client_up client
kubectl delete -f deploy/k8s/lessons/broken-echo.yaml --ignore-not-found --grace-period=1 >/dev/null
show kubectl apply -f deploy/k8s/lessons/broken-echo.yaml
kubectl wait --for=condition=Ready pod/caller -n network-lessons --timeout=180s >/dev/null
echo
# client_get <url>: what wget in client says, error included.
client_get() {
  echo "\$ kubectl exec client -n network-lessons -- wget -T 5 -qO- $1"
  kubectl exec client -n network-lessons -- wget -T 5 -qO- "$1" 2>&1 | grep -v '^command terminated' || true
}
slices() {
  show kubectl get endpointslices -n network-lessons -l "kubernetes.io/service-name=$1" \
    -o 'custom-columns=NAME:.metadata.labels.kubernetes\.io/service-name,ADDRESSES:.endpoints[*].addresses[0],PORT:.ports[0].port'
}

# lesson: k8s.l3.debugging-pod-networking
# One: connection refused, and an empty EndpointSlice. The Service's
# selector matches no Pod: compare it with the Pods' labels.
echo "== broken-selector"
client_get http://broken-selector
slices broken-selector
show kubectl get service broken-selector -n network-lessons -o jsonpath='{.spec.selector}{"\n"}'
show kubectl get pods -n network-lessons -l app=echo-ip -o custom-columns=POD:.metadata.name,LABELS:.metadata.labels.app
echo

# lesson: k8s.l3.debugging-pod-networking
# Two: refused again, but the EndpointSlice lists both Pods, on port 80.
# A Pod's own address on the port it listens on answers, skipping the
# Service: the Service's targetPort is wrong.
echo "== broken-port"
client_get http://broken-port
slices broken-port
pod_ip=$(kubectl get pods -n network-lessons -l app=echo-ip -o jsonpath='{.items[0].status.podIP}')
client_get "http://$pod_ip:8080"
echo

# lesson: k8s.l3.debugging-pod-networking
# Three: caller cannot reach echo-ip, yet from client, a Pod no policy
# selects, everything works. kubectl debug adds a container with tools to
# caller itself: same network, same policies. There the name does not
# resolve while the cluster IP answers: the policy has no rule for DNS.
echo "== caller"
echo "\$ kubectl exec client -n network-lessons -- getent hosts echo-ip"
kubectl exec client -n network-lessons -- getent hosts echo-ip >/dev/null && echo "(resolves)"
cluster_ip=$(kubectl get service echo-ip -n network-lessons -o jsonpath='{.spec.clusterIP}')
echo "\$ kubectl debug caller -n network-lessons --profile=general --image=caddy:2.10.0 --target=caller -c debug \\"
echo "    -- sh -c 'getent hosts echo-ip || echo \"echo-ip: no address\"; wget -T 5 -qO- http://<echo-ip's cluster IP>'"
kubectl debug caller -n network-lessons --profile=general --image=caddy:2.10.0 --target=caller -c debug \
  -- sh -c "getent hosts echo-ip || echo 'echo-ip: no address'; wget -T 5 -qO- http://$cluster_ip" >/dev/null 2>&1
# The temporary container runs on its own; its output is in its log.
until [ -n "$(kubectl get pod caller -n network-lessons \
    -o jsonpath='{.status.ephemeralContainerStatuses[?(@.name=="debug")].state.terminated.exitCode}')" ]; do
  sleep 1
done
show kubectl logs caller -n network-lessons -c debug
show kubectl get networkpolicy caller-egress -n network-lessons -o jsonpath='{.spec.egress}{"\n"}'

kubectl delete -f deploy/k8s/lessons/broken-echo.yaml --grace-period=1 --wait=false >/dev/null
kubectl delete pod client -n network-lessons --grace-period=1 --wait=false >/dev/null

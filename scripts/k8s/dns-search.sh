#!/usr/bin/env bash
# Turn on CoreDNS's log plugin and show the queries behind one lookup of example.com from a Pod (search domains first), then with a final dot, then from a Pod with ndots 1; last, a Pod with dnsPolicy Default.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang from here. Only for donhang: it edits CoreDNS's ConfigMap.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster
echo_ip_up
client_up client

# The log plugin goes after errors, and comes out again however the script
# ends; CoreDNS's reload plugin notices the ConfigMap's change within a
# minute or two.
corefile_log() {
  local expr='/^ *log$/d'
  [ "$1" = on ] && expr="$expr; s/^\( *\)errors\$/&\n\1log/"
  kubectl get configmap coredns -n kube-system -o yaml | sed "$expr" | kubectl replace -f - >/dev/null
}
trap 'corefile_log off' EXIT
# The queries a lookup from a Pod produced, as CoreDNS logged them: name
# and answer of each type A query, in the order they arrived at either
# CoreDNS Pod.
queries() {
  local pod_ip
  pod_ip=$(kubectl get pod "$1" -n network-lessons -o jsonpath='{.status.podIP}')
  for pod in $(kubectl get pods -n kube-system -l k8s-app=kube-dns -o name); do
    kubectl logs "$pod" -n kube-system --timestamps --since-time="$2"
  done | grep -F "] $pod_ip:" | sort \
    | sed -E 's/.*"([A-Z]+) IN ([^ ]+) .*" ([A-Z]+) .*/\1 \2 \3/' | awk '$1 == "A" && !seen[$0]++ { print $2, $3 }'
}
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
lookup() {
  local pod=$1 name=$2 since
  since=$(now); sleep 1
  echo "\$ kubectl exec $pod -n network-lessons -- getent ahostsv4 $name"
  kubectl exec "$pod" -n network-lessons -- getent ahostsv4 "$name" >/dev/null || echo "(no address)"
  sleep 2
  echo "queries CoreDNS logged:"
  queries "$pod" "$since" | sed 's/^/  /'
}

# lesson: k8s.l3.dns-search-and-ndots
# The resolver settings the kubelet wrote for a Pod with the default
# dnsPolicy, ClusterFirst: three search domains and ndots:5.
show kubectl exec client -n network-lessons -- cat /etc/resolv.conf
echo

# Wait until both CoreDNS Pods log: ask each one directly for a name of
# its own until that query shows in its log.
corefile_log on
for pod in $(kubectl get pods -n kube-system -l k8s-app=kube-dns -o name); do
  ip=$(kubectl get "$pod" -n kube-system -o jsonpath='{.status.podIP}')
  until kubectl logs "$pod" -n kube-system --since=1m | grep -q "log-check-${pod##*-}"; do
    kubectl exec client -n network-lessons -- nslookup "log-check-${pod##*-}.invalid." "$ip" >/dev/null 2>&1 || true
    sleep 5
  done
done

# lesson: k8s.l3.dns-search-and-ndots
# example.com has one dot, fewer than five: every search domain is tried
# first, each answered NXDOMAIN, and the name as written comes last.
lookup client example.com
echo
# A final dot marks the name as complete: one query.
lookup client example.com.
echo

# lesson: k8s.l3.dns-search-and-ndots
# ndots 1 in the Pod's dnsConfig: example.com is tried as written first.
kubectl delete pod dns-ndots dns-node -n network-lessons --ignore-not-found --grace-period=1 >/dev/null
show kubectl apply -f deploy/k8s/lessons/dns-config-pod.yaml
kubectl wait --for=condition=Ready pod/dns-ndots pod/dns-node -n network-lessons --timeout=180s >/dev/null
show kubectl exec dns-ndots -n network-lessons -- grep options /etc/resolv.conf
lookup dns-ndots example.com
echo

# lesson: k8s.l3.dns-search-and-ndots
# dnsPolicy Default: the node's resolver, no search domains for the
# cluster, and the name of a Service in the same namespace resolves no more.
echo "\$ kubectl exec dns-node -n network-lessons -- grep -v -e '^#' -e '^$' /etc/resolv.conf"
kubectl exec dns-node -n network-lessons -- grep -v -e '^#' -e '^$' /etc/resolv.conf
echo "\$ kubectl exec dns-node -n network-lessons -- getent hosts echo-ip"
kubectl exec dns-node -n network-lessons -- getent hosts echo-ip 2>/dev/null || echo "(no address)"
echo "\$ kubectl exec client -n network-lessons -- getent hosts echo-ip"
kubectl exec client -n network-lessons -- getent hosts echo-ip >/dev/null && echo "(resolves to echo-ip's cluster IP)"

kubectl delete pod client dns-ndots dns-node -n network-lessons --grace-period=1 --wait=false >/dev/null

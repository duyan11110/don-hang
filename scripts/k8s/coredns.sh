#!/usr/bin/env bash
# Show CoreDNS (its Pods, the Service kube-dns a Pod's resolv.conf names, its Corefile), resolve a Service created a second ago, then scale CoreDNS to zero: names fail, Pod IPs still work.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster
echo_ip_up
client_up client
# However the script ends, CoreDNS gets its two Pods back.
restore() {
  kubectl scale deployment coredns -n kube-system --replicas=2 >/dev/null
  kubectl rollout status deployment coredns -n kube-system --timeout=180s >/dev/null
}
trap restore EXIT

# lesson: k8s.l3.coredns
# The cluster's DNS server: CoreDNS Pods in kube-system, behind the Service
# kube-dns. Every Pod's resolv.conf names that Service's address.
show kubectl get pods -n kube-system -l k8s-app=kube-dns -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[0].image
show kubectl get service kube-dns -n kube-system
show kubectl exec client -n network-lessons -- grep nameserver /etc/resolv.conf
echo

# lesson: k8s.l3.coredns
# The Corefile, from the ConfigMap coredns: one server block for every
# name (.:53), one plugin per line.
echo "\$ kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}'"
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}'
echo

# lesson: k8s.l3.coredns
# The kubernetes plugin answers from what the API server holds: a Service
# created a moment ago resolves at once, with no DNS record written by hand.
kubectl delete service echo-new -n network-lessons --ignore-not-found >/dev/null
show kubectl create service clusterip echo-new -n network-lessons --tcp=80:8080
show kubectl exec client -n network-lessons -- getent hosts echo-new.network-lessons.svc.cluster.local
kubectl delete service echo-new -n network-lessons >/dev/null
echo

# lesson: k8s.l3.coredns
# No CoreDNS Pod: no name resolves, yet a connection to a Pod's address,
# which needs no lookup, still works.
pod_ip=$(kubectl get pods -n network-lessons -l app=echo-ip -o jsonpath='{.items[0].status.podIP}')
show kubectl scale deployment coredns -n kube-system --replicas=0
kubectl wait --for=delete pod -n kube-system -l k8s-app=kube-dns --timeout=120s >/dev/null
echo "\$ kubectl exec client -n network-lessons -- getent hosts echo-ip"
kubectl exec client -n network-lessons -- getent hosts echo-ip 2>&1 || echo "(no answer: exit $?)"
echo "\$ kubectl exec client -n network-lessons -- wget -qO- http://<an echo-ip Pod's address>:8080"
kubectl exec client -n network-lessons -- wget -qO- "http://$pod_ip:8080"

kubectl delete pod client -n network-lessons --grace-period=1 --wait=false >/dev/null

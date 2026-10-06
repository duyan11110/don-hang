#!/usr/bin/env bash
# Call echo-loadbalancer (Cluster) and echo-loadbalancer-local (Local) from the client container: the address echo-ip reports, which Pods answer, and which node announces Local's address.
# Runs on the host, like every script in scripts/k8s/: kubectl and docker talk to the cluster donhang and its Docker network from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster
echo_ip_up
metallb_up
# However the script ends, echo-ip gets its two replicas back.
trap 'kubectl scale deployment echo-ip -n network-lessons --replicas=2 >/dev/null' EXIT
kubectl apply -f deploy/k8s/lessons/echo-loadbalancer.yaml >/dev/null
show kubectl apply -f deploy/k8s/lessons/echo-loadbalancer-local.yaml
for _ in $(seq 60); do [ -n "$(lb_ip echo-loadbalancer-local)" ] && break; sleep 1; done
show kubectl get services echo-loadbalancer echo-loadbalancer-local -n network-lessons   -o custom-columns=NAME:.metadata.name,EXTERNAL-IP:.status.loadBalancer.ingress[0].ip,POLICY:.spec.externalTrafficPolicy
echo "the client container's address: $(docker inspect -f '{{(index .NetworkSettings.Networks "kind").IPAddress}}' donhang-lb-client)"
echo

# lesson: k8s.l3.external-traffic-policy
# Cluster: the receiving node may pass the connection to a Pod on another
# node and puts its own address in place of the client's. Local: the
# client's own address arrives.
for svc in echo-loadbalancer echo-loadbalancer-local; do
  echo "\$ docker exec donhang-lb-client wget -qO- http://<$svc's address>"
  lb_get "$(lb_ip "$svc")"
done
echo

# lesson: k8s.l3.external-traffic-policy
# Ten calls to each: with Cluster both Pods answer; with Local only the Pod
# on the announcing node does, though echo-ip runs on both workers.
for svc in echo-loadbalancer echo-loadbalancer-local; do
  ip=$(lb_ip "$svc")
  pods=$(for _ in $(seq 10); do lb_get "$ip"; done | awk '{ print $1 }' | sort -u | wc -l)
  echo "$svc (announced by $(lb_node "$svc")): 10 calls, Pods that answered: $pods"
done
echo

# lesson: k8s.l3.external-traffic-policy
# One echo-ip Pod left: only the node that runs it may announce the Local
# Service's address.
show kubectl scale deployment echo-ip -n network-lessons --replicas=1
kubectl wait --for=delete pod -n network-lessons -l app=echo-ip --field-selector status.phase=Running --timeout=5s >/dev/null 2>&1 || true
for _ in $(seq 60); do
  [ "$(kubectl get pods -n network-lessons -l app=echo-ip --no-headers | wc -l)" = 1 ] && break
  sleep 1
done
pod_node=$(kubectl get pods -n network-lessons -l app=echo-ip -o jsonpath='{.items[0].spec.nodeName}')
for _ in $(seq 60); do [ "$(lb_node echo-loadbalancer-local)" = "$pod_node" ] && break; sleep 1; done
echo "the echo-ip Pod runs on $pod_node; echo-loadbalancer-local is announced by $(lb_node echo-loadbalancer-local)"

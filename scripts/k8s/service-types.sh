#!/usr/bin/env bash
# Put echo-ip behind a NodePort and a LoadBalancer Service, call the control-plane node (no echo-ip Pod there) on the node port, and show EXTERNAL-IP stuck at <pending>.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster
# The lessons of k8s/bare-metal install MetalLB on donhang, which would give
# the LoadBalancer an address: this lesson shows a cluster without it.
if kubectl get namespace metallb-system >/dev/null 2>&1; then
  kubectl delete -f deploy/metallb/metallb-native.yaml --ignore-not-found --wait=true >/dev/null 2>&1 || true
fi
echo_ip_up
client_up client

# lesson: k8s.l3.service-types
# A NodePort Service: Kubernetes picked the node port, shown after the
# colon in PORT(S).
kubectl delete service echo-nodeport echo-loadbalancer -n network-lessons --ignore-not-found >/dev/null
show kubectl apply -f deploy/k8s/lessons/echo-nodeport.yaml
show kubectl get service echo-nodeport -n network-lessons
node_port=$(kubectl get service echo-nodeport -n network-lessons -o jsonpath='{.spec.ports[0].nodePort}')
echo

# lesson: k8s.l3.service-types
# Both echo-ip Pods run on the workers; the control-plane node runs none,
# yet its node port answers: kube-proxy there forwards to a Pod elsewhere.
show kubectl get pods -n network-lessons -l app=echo-ip -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName
cp_ip=$(kubectl get node donhang-control-plane -o jsonpath='{.status.addresses[0].address}')
echo "\$ kubectl exec client -n network-lessons -- wget -qO- http://<donhang-control-plane's address>:<node port>"
kubectl exec client -n network-lessons -- wget -qO- "http://$cp_ip:$node_port"
echo

# lesson: k8s.l3.service-types
# A LoadBalancer Service asks for an outside address. kind has no controller
# to hand one out, so EXTERNAL-IP stays <pending>; the cluster IP and the
# node port work all the same.
show kubectl apply -f deploy/k8s/lessons/echo-loadbalancer.yaml
sleep 10
show kubectl get service echo-loadbalancer -n network-lessons
lb_port=$(kubectl get service echo-loadbalancer -n network-lessons -o jsonpath='{.spec.ports[0].nodePort}')
echo "\$ kubectl exec client -n network-lessons -- wget -qO- http://echo-loadbalancer"
kubectl exec client -n network-lessons -- wget -qO- http://echo-loadbalancer
echo "\$ kubectl exec client -n network-lessons -- wget -qO- http://<donhang-control-plane's address>:<its node port>"
kubectl exec client -n network-lessons -- wget -qO- "http://$cp_ip:$lb_port"

kubectl delete pod client -n network-lessons --grace-period=1 --wait=false >/dev/null

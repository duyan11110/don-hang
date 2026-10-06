#!/usr/bin/env bash
# Show echo-ip's EndpointSlice and the iptables rules kube-proxy wrote for it on a node, then compare ten new connections (both Pods answer) with ten requests on one kept-open connection (one Pod).
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang, and docker reads a node container's rules, from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster
echo_ip_up
client_up client

# lesson: k8s.l3.kube-proxy
# The Service's cluster IP, and the EndpointSlice the control plane keeps
# for it: one entry per Pod the selector matches, with whether it is ready.
show kubectl get service echo-ip -n network-lessons
show kubectl get endpointslices -n network-lessons -l kubernetes.io/service-name=echo-ip \
  -o 'custom-columns=ADDRESSES:.endpoints[*].addresses[0],READY:.endpoints[*].conditions.ready,PORT:.ports[0].port'
echo

# lesson: k8s.l3.kube-proxy
# kube-proxy runs in iptables mode here. On every node it wrote rules for
# the cluster IP: send it to the Service's chain; there, one entry per Pod,
# the first taken with probability 0.5; each entry rewrites the destination
# to its Pod's address and port (DNAT).
echo "\$ kubectl get configmap kube-proxy -n kube-system -o jsonpath='{.data.config\.conf}' | grep '^mode'"
kubectl get configmap kube-proxy -n kube-system -o jsonpath='{.data.config\.conf}' | grep '^mode'
echo "\$ docker exec donhang-worker iptables-save -t nat | grep 'network-lessons/echo-ip ' (comments cut)"
docker exec donhang-worker iptables-save -t nat | grep -F '"network-lessons/echo-ip ' \
  | grep -e '-A KUBE-SERVICES' -e '-A KUBE-SVC-.* -j KUBE-SEP' | sed -E 's/ -m comment --comment "[^"]*"//'
docker exec donhang-worker iptables-save -t nat | grep -F '"network-lessons/echo-ip"' \
  | grep DNAT | sed -E 's/ -m comment --comment "[^"]*"//'
echo

# lesson: k8s.l3.kube-proxy
# Ten requests, each on a new connection: each connection picks a Pod.
echo "\$ for i in \$(seq 10); do kubectl exec client -n network-lessons -- wget -qO- http://echo-ip; done"
for i in $(seq 10); do
  kubectl exec client -n network-lessons -- wget -qO- http://echo-ip
done | awk '{ print $1 }' | sort -u | awk '{ n++ } END { print "different Pods that answered: " n }'

# Ten requests on one connection kept open (HTTP keep-alive, written by
# hand and sent with nc): the Pod was picked once, when it opened.
requests='for i in $(seq 9); do printf "GET / HTTP/1.1\r\nHost: echo-ip\r\n\r\n"; done
printf "GET / HTTP/1.1\r\nHost: echo-ip\r\nConnection: close\r\n\r\n"'
echo "\$ kubectl exec client -n network-lessons -- sh -c '(ten requests) | nc echo-ip 80'"
kubectl exec client -n network-lessons -- sh -c "($requests) | nc echo-ip 80" \
  | grep ' saw ' | awk '{ print $1 }' \
  | awk '!seen[$1]++ { pods++ } { n++ } END { print "answers: " n ", different Pods that answered: " pods }'
echo

# lesson: k8s.l3.kube-proxy
# A headless Service has no cluster IP, so kube-proxy writes no rule for it.
kubectl apply -f - >/dev/null <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: echo-ip-headless
  namespace: network-lessons
spec:
  clusterIP: None
  selector:
    app: echo-ip
  ports:
    - port: 8080
YAML
show kubectl get service echo-ip-headless -n network-lessons
sleep 2
echo "rules for echo-ip-headless on donhang-worker: $(docker exec donhang-worker iptables-save -t nat | grep -c 'network-lessons/echo-ip-headless' || true)"

kubectl delete service echo-ip-headless -n network-lessons --wait=false >/dev/null
kubectl delete pod client -n network-lessons --grace-period=1 --wait=false >/dev/null

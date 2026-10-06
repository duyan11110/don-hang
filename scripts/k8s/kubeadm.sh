#!/usr/bin/env bash
# Read, on donhang-control-plane, what kubeadm set up: the kubelet and container runtime it found, the static Pod manifests, the certificate authority and certificates, and their expiry dates. Changes nothing.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang, and docker exec reads the control-plane node's files, from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster
node() { echo "\$ docker exec donhang-control-plane $*"; docker exec donhang-control-plane "$@"; }

# lesson: k8s.l3.kubeadm
# kind built each node with kubeadm, from the configuration it wrote to
# /kind/kubeadm.conf. kubeadm found the kubelet and the container runtime
# (containerd) already installed and running.
node kubeadm version -o short
node systemctl is-active kubelet containerd
node grep -m 1 '^kind:' /kind/kubeadm.conf
echo

# lesson: k8s.l3.kubeadm
# Static Pods: the kubelet starts the control plane from these files, with
# no API server to ask. The API server then shows a copy of each, named
# after the node.
node ls /etc/kubernetes/manifests
show kubectl get pods -n kube-system -l tier=control-plane -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName
echo

# lesson: k8s.l3.kubeadm
# The certificate authorities (ca, etcd/ca, front-proxy-ca) kubeadm init
# created, and the certificates it signed with them for the components.
node ls /etc/kubernetes/pki /etc/kubernetes/pki/etcd
echo

# lesson: k8s.l3.kubeadm
# Certificates expire one year after they were signed, the authorities ten
# years after.
node kubeadm certs check-expiration 2>/dev/null | grep -v '^\[check-expiration\]'

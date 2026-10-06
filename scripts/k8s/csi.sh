#!/usr/bin/env bash
# Show the driver behind kind's StorageClass standard: rancher.io/local-path, which runs as one Pod and is not a CSI driver; kubectl get csidrivers lists none.
# Runs on the host, like every script in scripts/k8s/: kubectl talks to the cluster donhang from here.
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/network-lessons.sh
lessons_cluster

# lesson: k8s.l3.csi-drivers
# A StorageClass names the driver that creates its volumes: provisioner.
show kubectl get storageclasses -o custom-columns=NAME:.metadata.name,PROVISIONER:.provisioner
echo

# lesson: k8s.l3.csi-drivers
# rancher.io/local-path is kind's own provisioner, one Pod that creates
# folders on the nodes. A CSI driver registers itself with a CSIDriver
# object; this cluster has none.
show kubectl get pods -n local-path-storage -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName
echo "\$ kubectl get csidrivers"
kubectl get csidrivers 2>&1

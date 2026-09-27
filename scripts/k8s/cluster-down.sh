#!/usr/bin/env bash
# Delete the kind cluster named donhang and every node container it runs; no lesson object survives this.
# Runs on the host, like scripts/k8s/cluster-up.sh.
set -euo pipefail

if kind get clusters 2>/dev/null | grep -qx donhang; then
  kind delete cluster --name donhang 2>&1
else
  echo "There is no cluster named donhang."
fi

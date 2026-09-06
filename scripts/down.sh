#!/usr/bin/env bash
# Stop the Đơn Hàng lab and remove its containers, network and volumes.
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose down --volumes --remove-orphans
echo "The lab is down."

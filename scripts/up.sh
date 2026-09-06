#!/usr/bin/env bash
# Start the Đơn Hàng lab: the static site, the database and the lab box.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/dev-secrets.sh

docker compose up -d --build --wait

echo
echo "The lab is up."
echo "  site        http://localhost:8080/"
echo "  site (TLS)  https://donhang.local:8443/   (add '127.0.0.1 donhang.local' to your hosts file)"
echo "  database    postgres://donhang@localhost:5432/donhang"
echo "  lab box     ssh -p 2222 -i secrets/lab_key dev@localhost"
echo
echo "Run a lesson's command with, for example: scripts/http/methods.sh"

#!/usr/bin/env bash
# Start the Đơn Hàng lab: the static site, the database and the lab box.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/dev-secrets.sh

# lesson: frontend.l1.the-widget-tree
# The app-web container only serves files; building them needs the Flutter
# SDK, which runs on the host, not in a container (D5/D7: Flutter is a
# prerequisite here, same as Docker Desktop).
(cd DonHang.App && flutter build web >/dev/null)

docker compose up -d --build --wait

echo
echo "The lab is up."
echo "  site        http://localhost:8080/"
echo "  site (TLS)  https://donhang.local:8443/   (add '127.0.0.1 donhang.local' to your hosts file)"
echo "  app (web)   http://localhost:8081/"
echo "  database    postgres://donhang@localhost:5432/donhang"
echo "  lab box     ssh -p 2222 -i secrets/lab_key dev@localhost"
echo
echo "Run a lesson's command with, for example: scripts/http/methods.sh"

#!/usr/bin/env bash
# Open a shell on the lab box over SSH and run three commands there, not here.
set -euo pipefail
cd "$(dirname "$0")/../.."

ssh -p 2222 -i secrets/lab_key \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    dev@localhost 'hostname; whoami; ls -1 /repo/db'

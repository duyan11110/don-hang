#!/usr/bin/env bash
# Where a program looks for a file, and who is allowed to open it.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

rm -rf /tmp/demo
mkdir -p /tmp/demo
cd /tmp/demo
printf 'port=8080\n' > app.conf

echo "who is this process running as: $(whoami)"
stat -c '%A %U:%G %n' app.conf

chmod 600 app.conf
stat -c '%A %U:%G %n' app.conf

echo
echo "working directory: $(pwd)"
echo "a relative path is resolved from there:"
cat app.conf

cd /
echo "working directory: $(pwd)"
cat app.conf 2>&1 || echo "the same relative path now finds nothing"
cat /tmp/demo/app.conf

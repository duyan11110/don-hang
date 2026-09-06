#!/usr/bin/env bash
# A port is a door with a number: which doors have someone behind them?
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

for target in localhost:8080 localhost:8443 localhost:2222 db:5432 localhost:9999; do
  host="${target%:*}"
  port="${target##*:}"
  if nc -z -w 3 "$host" "$port" 2>/dev/null; then
    echo "$target is open"
  else
    echo "$target is closed"
  fi
done

echo
echo "the listening sockets of this box:"
netstat -tln | grep -E ':(2222|8080|8443) ' | sort

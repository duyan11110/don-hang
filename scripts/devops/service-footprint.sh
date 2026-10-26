#!/usr/bin/env bash
# List, grouped by area (CI, Compose, manifests, NetworkPolicies, routes, sealed secrets, OpenTofu, scripts), every file outside a service's own code that names the service, and how many there are: what adding that service took besides its code.
# Usage: scripts/devops/service-footprint.sh [service]   (default: payments; or notifications, api)
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"
cd "$(dirname "$0")/../.."

service=${1:-payments}
# The service's own code: DonHang.Payments/ for payments.
own="DonHang.${service^}"

# lesson: devops.l4.platform-engineering
# Every file that names the service, ignoring case (payments, donhang_payments,
# DonHang.Payments), sorted into the area it belongs to. Docs, tests and the
# lessons' own scripts are left out: they did not have to change to run it.
area() {
  case "$1" in
    .github/*) echo "CI" ;;
    deploy/tofu/*) echo "OpenTofu" ;;
    deploy/*/httproutes.yaml | Caddyfile | deploy/*/Caddyfile) echo "route" ;;
    deploy/*) if grep -q '^kind: NetworkPolicy' "$1"; then echo "NetworkPolicy"; else echo "Kustomize and manifests"; fi ;;
    docker-compose*.yml | db/databases.sql) echo "Compose" ;;
    scripts/devops/seal-secrets.sh) echo "sealed secret" ;;
    scripts/up.sh | scripts/dev-secrets.sh | scripts/devops/*) echo "script" ;;
  esac
}

# Where such files live: CI, Compose and its database setup, the manifests
# and OpenTofu under deploy/ (not the providers tofu init downloads), the
# scripts that run the lab and its backups.
files=$(find .github deploy docker-compose*.yml Caddyfile db/databases.sql scripts/up.sh scripts/dev-secrets.sh scripts/devops \
          -name .terraform -prune -o -type f ! -name service-footprint.sh -print \
        | xargs grep -lis "$service" | sort)
listed=$(while read -r file; do
  group=$(area "$file")
  [ -n "$group" ] && echo "$group|$file"
done <<< "$files")

echo "== files outside $own/ that name $service"
for group in "CI" "Compose" "Kustomize and manifests" "NetworkPolicy" "route" "sealed secret" "OpenTofu" "script"; do
  in_group=$(echo "$listed" | awk -F'|' -v g="$group" '$1 == g {print $2}')
  [ -n "$in_group" ] || { echo "$group: none"; continue; }
  echo "$group: $(echo "$in_group" | wc -l)"
  echo "$in_group" | sed 's/^/  /'
done
echo "total: $(echo "$listed" | grep -c .) files"

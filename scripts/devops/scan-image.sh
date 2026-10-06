#!/usr/bin/env bash
# Scan an image's SBOM (default: the api's, from sbom.sh) with Grype, and fail when a High or Critical vulnerability has a fixed version.
# Runs on the host: Grype runs in its own container and reads the SBOM, not the image. CI's image job runs this same script.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1 LC_ALL=C

sbom=${1:-sbom/donhang-api.cdx.json}
[ -f "$sbom" ] || scripts/devops/sbom.sh >/dev/null

# Grype sees this repository read-only, so it finds .grype.yaml in the
# directory it runs in; its vulnerability database is kept in a volume.
grype_image=anchore/grype:v0.120.0@sha256:5c88961f4130e830542d441c7ed6c78baa28e799163abac53d2be4923fb5ab7d
docker pull --quiet "$grype_image" >/dev/null
grype() {
  docker run --rm --volume "$(pwd -W 2>/dev/null || pwd):/repo:ro" --workdir /repo \
    --volume donhang-grype-db:/grype-db --env GRYPE_DB_CACHE_DIR=/grype-db \
    "$grype_image" "$@"
}

# The result depends on the database: the same SBOM can scan clean today and
# show a finding once a new vulnerability is published.
grype db update >/dev/null
echo "== vulnerability database built: $(grype db status | sed -n 's/^Built: *//p')"

echo "== every known vulnerability in $sbom, fixed or not, by severity"
all=$(grype "sbom:$sbom" --quiet --show-suppressed)
for severity in Critical High Medium Low Negligible Unknown; do
  printf '%-10s %s\n' "$severity" "$(grep -v '(suppressed)' <<<"$all" | grep -c " $severity " || true)"
done
echo "== accepted in .grype.yaml"
grep '(suppressed)' <<<"$all" | while read -r package rest; do
  echo "  $package $(grep -oE '(CVE|GHSA)-[A-Za-z0-9-]+' <<<"$rest" | head -n 1)"
done | sort -u

# lesson: devops.l3.vulnerability-scanning
# The gate: only vulnerabilities with a fixed version, and the scan fails on
# High or Critical. Grype exits non-zero then, and so does this script.
echo "== High or Critical with a fixed version"
status=0
blocking=$(grype "sbom:$sbom" --quiet --only-fixed --fail-on high) || status=$?
if [ "$status" -ne 0 ]; then
  printf '%s\n' "$blocking"
  echo "scan failed: update the package or base image, or accept the finding in .grype.yaml with a reason" >&2
  exit "$status"
fi
echo "none: the scan passes"

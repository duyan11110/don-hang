#!/usr/bin/env bash
# Print one version's section of CHANGELOG.md, as in scripts/release-notes.sh 1.0.0; fail if it has none.
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:?usage: scripts/release-notes.sh <version, such as 1.0.0>}"

# lesson: devops.l2.cutting-a-release
# A version's section starts below its "## [1.0.0]" heading and ends at the
# next "## [" heading. The heading itself is left out: the release has a title.
notes=$(awk -v heading="## [$version]" '
  index($0, "## [") == 1 { inside = (index($0, heading) == 1); started = 0; next }
  inside && (started || NF > 0) { started = 1; print }
' CHANGELOG.md)

# No section, or an empty one: a release without notes is a mistake, so stop.
if [ -z "$notes" ]; then
  echo "CHANGELOG.md has no section for version $version" >&2
  exit 1
fi
echo "$notes"

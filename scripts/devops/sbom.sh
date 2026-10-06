#!/usr/bin/env bash
# Write an image's software bill of materials (SBOM) as CycloneDX JSON with Syft, then show what kinds of components it lists.
# Runs on the host: Syft, in its own container, reads the image from the local Docker engine. CI's image job runs this same script.
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1 LC_ALL=C

# The api image as docker-compose.yml names it, unless another is given;
# the SBOM goes to sbom/ (gitignored) unless another file is given.
image=${1:-donhang-api:stage-2}
out=${2:-sbom/$(basename "${image%%:*}").cdx.json}
if ! docker image inspect "$image" >/dev/null 2>&1; then
  echo "no image $image on this Docker engine: build it first (docker compose build api)" >&2
  exit 1
fi
mkdir -p "$(dirname "$out")"

# lesson: devops.l3.software-bill-of-materials
# Syft runs from its own image, named by digest like any base image. It reads
# the image through the Docker engine's socket and writes the SBOM, in the
# CycloneDX JSON format, to standard output.
syft=anchore/syft:v1.54.0@sha256:0356562f495d432056237fbea5cbc2d4839c9c75cd500784a66de2e7cc95ca7c
docker pull --quiet "$syft" >/dev/null
docker run --rm --volume /var/run/docker.sock:/var/run/docker.sock "$syft" \
  scan "docker:$image" --output cyclonedx-json --quiet > "$out"
echo "== $image -> $out"

# Every component has a package URL: pkg:deb/... for an OS package from the
# base image, pkg:nuget/... for a NuGet package inside the published app.
purls() { grep -o '"purl":"pkg:[^"]*' "$out" | cut -d'"' -f4; }
echo "== components by kind"
purls | cut -d/ -f1 | sort | uniq -c

# The packages Directory.Packages.props names, and the ones the image holds
# although no project file asks for them: transitive dependencies.
echo "== NuGet packages in the image that Directory.Packages.props does not list"
declared=$(grep -o 'PackageVersion Include="[^"]*"' Directory.Packages.props | cut -d'"' -f2)
purls | grep '^pkg:nuget/' | sed 's|^pkg:nuget/||; s|@| |' | sort -f \
  | while read -r name version; do
      case $name in DonHang.*) continue ;; esac  # Đơn Hàng's own code
      grep -qxF "$name" <<<"$declared" || echo "  $name $version"
    done

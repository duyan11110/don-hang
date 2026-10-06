#!/usr/bin/env bash
# Verify an image's keyless signature and build provenance with Cosign: only ci.yml on master of Đơn Hàng's repository is accepted.
# Runs on the host: Cosign runs in its own container and needs ghcr.io and Sigstore, but no login (the images are public).
# Usage: scripts/devops/verify-image.sh [image]   (exit 1 when it does not verify; default: the newest sha- api image, then the api's 1.0.0)
set -euo pipefail
cd "$(dirname "$0")/../.."
export MSYS_NO_PATHCONV=1
source scripts/lib/images.sh

cosign_image=ghcr.io/sigstore/cosign/cosign:v3.1.3@sha256:9e5c2f2edc34351160407ca3416c61855bdf9403c3c5936e0f0be7fc261611b8
docker pull --quiet "$cosign_image" >/dev/null
cosign() { docker run --rm "$cosign_image" "$@"; }

# lesson: devops.l3.signing-images
# Anyone can get a keyless signature for their own identity, so a valid
# signature proves nothing until the certificate's identity is checked:
# exactly ci.yml, on master, of this repository, as GitHub's token issuer
# vouched for it.
identity=https://github.com/duyan11110/don-hang/.github/workflows/ci.yml@refs/heads/master
issuer=https://token.actions.githubusercontent.com
trusted=(--certificate-identity "$identity" --certificate-oidc-issuer "$issuer")

verify() {
  local ref=$1 digest payload
  # Always a digest: a tag can be moved to another image after the check.
  if [[ $ref == *@sha256:* ]]; then digest=${ref#*@}; else digest=$(digest_of "$ref"); fi
  [ -n "$digest" ] || { echo "no image $ref"; return 1; }
  echo "== $ref -> ${ref%%[:@]*}@$digest"

  echo "-- signature"
  cosign verify "${ref%%[:@]*}@$digest" "${trusted[@]}" 2>&1 >/dev/null | grep -v '^$' || return 1

  # lesson: devops.l3.build-provenance
  # The SLSA provenance attestation for the same digest, signed by the same
  # identity; then what it states: the repository and workflow that built it.
  echo "-- provenance"
  payload=$(cosign verify-attestation "${ref%%[:@]*}@$digest" --type slsaprovenance1 "${trusted[@]}" \
    2>/dev/null | head -n 1 | sed -nE 's/.*"payload":"([^"]+)".*/\1/p' | base64 -d) \
    || { echo "no provenance from ci.yml for this digest"; return 1; }
  grep -q '"repository":"https://github.com/duyan11110/don-hang"' <<<"$payload" \
    && grep -q '"path":".github/workflows/ci.yml"' <<<"$payload" \
    || { echo "the provenance names another repository or workflow"; return 1; }
  echo "built by $(grep -oE '"repository":"[^"]+"' <<<"$payload" | cut -d'"' -f4)," \
    "$(grep -oE '"path":"[^"]+"' <<<"$payload" | cut -d'"' -f4)" \
    "at commit $(grep -oE '"gitCommit":"[0-9a-f]+"' <<<"$payload" | cut -d'"' -f4)" \
    "($(grep -oE '"event_name":"[^"]+"' <<<"$payload" | cut -d'"' -f4))"
  echo "verified"
}

if [ $# -gt 0 ]; then
  verify "$1"
  exit
fi

# No image given: a sha- image from stage-3, which verifies, then 1.0.0,
# pushed before stage-3 without a signature or provenance, which must not.
verify "$registry/donhang-api:$(newest_published_tag)"
echo
if verify "$registry/donhang-api:1.0.0"; then
  echo "1.0.0 verified, but it was never signed" >&2
  exit 1
fi
echo "not verified: refused"

#!/usr/bin/env bash
# Render the golden path's Kustomize files for a new .NET service from templates/dotnet-service/ into a temporary folder, then check them as CI checks the config repository: kubectl kustomize, kubeconform, images by digest.
# Runs on the host: kubectl renders the files here, and kubeconform runs from its image on the local Docker engine, as in CI's manifests job.
# Usage: scripts/devops/new-service.sh [name] [image digest] [migration image digest]   (default name: invoices, an example)
#        (without digests, a placeholder of zeros: replace it with the digests CI published)
set -euo pipefail
cd "$(dirname "$0")/../.."
export LC_ALL=C

name=${1:-invoices}
zeros=$(printf '0%.0s' $(seq 64))
digest=${2:-$zeros}
migrate_digest=${3:-$zeros}
if ! [[ $name =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "a service name is lower case letters, digits and dashes, such as invoices" >&2
  exit 1
fi
out=$(mktemp -d)/$name
mkdir -p "$out"

# lesson: devops.l4.golden-path
# Rendering is copying the template and filling in the name and the
# digests. The files are the team's from then on: a later change to the
# template does not reach them.
for file in templates/dotnet-service/*.yaml; do
  sed -e "s/__SERVICE__/$name/g" -e "s/__DIGEST__/${digest#sha256:}/" -e "s/__MIGRATE_DIGEST__/${migrate_digest#sha256:}/" \
    "$file" > "$out/$(basename "$file")"
done
echo "== rendered for $name"
(cd "$out" && ls -1 | sed 's/^/  /')
echo

# lesson: devops.l4.golden-path
# The checks the config repository already gets in CI: the folder builds
# with kubectl kustomize, and kubeconform, the same pinned image as the
# manifests job, validates every object against Kubernetes 1.34.
kubeconform=$(sed -n 's/^ *KUBECONFORM: //p' .github/workflows/ci.yml)
echo "== kubectl kustomize | kubeconform"
kubectl kustomize "$out" > "$out.rendered.yaml"
docker run --rm -i "$kubeconform" -strict -summary -kubernetes-version 1.34.0 - < "$out.rendered.yaml"
echo

echo "== images in the rendered Pods"
sed -nE 's/^ *image: (.*)$/  \1/p' "$out.rendered.yaml" | sed -E 's/@sha256:0{64}$/@sha256:<placeholder>/'
if grep -E '^ *image: ghcr\.io/duyan11110/' "$out.rendered.yaml" | grep -qv '@sha256:'; then
  echo "an image of Đơn Hàng without a digest: the admission policy require-image-digest would refuse it" >&2
  exit 1
fi
echo "every image of Đơn Hàng named by digest: require-image-digest admits these Pods"
rm -rf "$(dirname "$out")" "$out.rendered.yaml"

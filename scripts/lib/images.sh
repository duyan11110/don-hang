# Plumbing, not a lesson: sourced by scripts/devops/verify-image.sh and
# scripts/devops/deploy-verified.sh. The caller has already done `cd` to the
# repository's root.

# Where ci.yml's publish job pushes Đơn Hàng's images.
registry=ghcr.io/duyan11110

# digest_of <image reference>: the digest the reference names in the
# registry right now (a tag can name another digest tomorrow). Empty when
# the registry has no such image.
digest_of() {
  docker buildx imagetools inspect "$1" 2>/dev/null | sed -n 's/^Digest: *//p' | head -n 1
}

# newest_published_tag: sha-<commit> for the newest commit in this clone's
# history whose api image ci.yml has already pushed.
newest_published_tag() {
  local commit
  for commit in $(git log --format=%H -n 30 HEAD); do
    if [ -n "$(digest_of "$registry/donhang-api:sha-$commit")" ]; then
      echo "sha-$commit"
      return 0
    fi
  done
  echo "no api image in $registry for the last 30 commits of this clone" >&2
  return 1
}

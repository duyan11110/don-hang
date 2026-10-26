#!/usr/bin/env bash
# Compute the four delivery metrics (deployment frequency, lead time for changes, change failure rate, time to restore) from Git history alone: a made-up quarter of a config repository's production deploys and reverts, and the application commits their sha- tags name.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

# Two throwaway repositories with fixed authors and dates, so that every
# commit id and every number below is the same on every run. The quarter is
# assumed: 13 weeks from Monday 2026-07-06.
work=/tmp/delivery-metrics
rm -rf "$work"
mkdir -p "$work/app" "$work/config"
export GIT_COMMITTER_EMAIL=lab@donhang.example GIT_AUTHOR_EMAIL=lab@donhang.example
at() { export GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1"; }

# The application repository: one commit per change; CI tags each commit's
# images sha-<commit>.
git -C "$work/app" init -q -b main
app_commit() { # app_commit <date> <message> -> prints the commit id
  at "$1"
  echo "$2" >> "$work/app/CHANGES"
  git -C "$work/app" add CHANGES
  GIT_AUTHOR_NAME=developer GIT_COMMITTER_NAME=developer git -C "$work/app" commit -q -m "$2"
  git -C "$work/app" rev-parse HEAD
}

# The config repository: envs/production names the api's tag, and each
# promotion is one commit by gitops-promote.sh, as in the lab.
git -C "$work/config" init -q -b main
mkdir -p "$work/config/envs/production"
set_tag() { printf 'images:\n  - name: ghcr.io/duyan11110/donhang-api\n    newTag: sha-%s\n' "$1" > "$work/config/envs/production/kustomization.yaml"; }
promote() { # promote <date> <app commit>
  at "$1"
  set_tag "$2"
  git -C "$work/config" add -A
  GIT_AUTHOR_NAME=gitops-promote.sh GIT_COMMITTER_NAME=gitops-promote.sh \
    git -C "$work/config" commit -q -m "Promote api sha-$2 to production"
}
revert() { # revert <date>: revert the newest commit, as gitops-revert.sh does
  at "$1"
  GIT_AUTHOR_NAME=gitops-revert.sh GIT_COMMITTER_NAME=gitops-revert.sh \
    git -C "$work/config" revert --no-edit HEAD >/dev/null
}

c=$(app_commit 2026-07-03T16:00:00+07:00 "Product list: page size 20")
at 2026-07-03T17:00:00+07:00; set_tag "$c"; git -C "$work/config" add -A
GIT_AUTHOR_NAME=gitops-repo.sh GIT_COMMITTER_NAME=gitops-repo.sh git -C "$work/config" commit -q -m "Production as Đơn Hàng runs it"

c=$(app_commit 2026-07-06T10:00:00+07:00 "Orders: v2 endpoint");            promote 2026-07-07T15:00:00+07:00 "$c"
c=$(app_commit 2026-07-13T09:30:00+07:00 "Refunds: retry once more");       promote 2026-07-14T10:00:00+07:00 "$c"
c=$(app_commit 2026-07-20T14:00:00+07:00 "Catalog: cache product 3 longer"); promote 2026-07-23T16:00:00+07:00 "$c"
revert 2026-07-23T16:45:00+07:00
c=$(app_commit 2026-07-24T09:00:00+07:00 "Catalog: cache key per shop");    promote 2026-07-28T10:00:00+07:00 "$c"
c=$(app_commit 2026-08-04T11:00:00+07:00 "Orders: idempotency key in logs"); promote 2026-08-05T09:30:00+07:00 "$c"
c=$(app_commit 2026-08-12T15:00:00+07:00 "Products: price in VND only");     promote 2026-08-18T10:00:00+07:00 "$c"
c=$(app_commit 2026-08-25T10:00:00+07:00 "Orders: status history paging");   promote 2026-08-26T14:00:00+07:00 "$c"
revert 2026-08-26T17:10:00+07:00
c=$(app_commit 2026-08-27T09:00:00+07:00 "Orders: history paging, fixed");   promote 2026-09-01T10:00:00+07:00 "$c"
c=$(app_commit 2026-09-08T13:00:00+07:00 "Refunds: reason field");          promote 2026-09-09T11:00:00+07:00 "$c"
c=$(app_commit 2026-09-21T10:00:00+07:00 "Catalog: search by name");        promote 2026-09-28T15:00:00+07:00 "$c"

echo "== the config repository: git log -- envs/production"
git -C "$work/config" log --reverse --format='%ad %h %an: %s' --date=format:'%Y-%m-%d %H:%M' -- envs/production \
  | sed -E 's/sha-([0-9a-f]{7})[0-9a-f]{33}/sha-\1.../'
echo

# lesson: devops.l4.delivery-metrics
# Every number comes from git log. A deploy is a commit that changes the
# image in envs/production, other than a revert; a revert marks the deploy
# it undoes as a failed change, and its time is when service was restored.
# Lead time runs from the application commit the sha- tag names.
deploys=0 failed=0 leads=() restores=()
declare -A deployed_at
while read -r commit time subject; do
  if [[ $subject == Revert* ]]; then
    undone=$(git -C "$work/config" show -s --format=%b "$commit" | sed -nE 's/^This reverts commit ([0-9a-f]+)\.$/\1/p')
    failed=$((failed + 1))
    restores+=($(( (time - deployed_at[$undone]) / 60 )))
    continue
  fi
  tag=$(git -C "$work/config" show --format= "$commit" -- envs/production | sed -nE 's/^\+ *newTag: sha-([0-9a-f]+)$/\1/p')
  [ -n "$tag" ] || continue
  [ "$(git -C "$work/config" rev-list --count "$commit")" -eq 1 ] && continue # the repository's first commit
  deploys=$((deploys + 1))
  deployed_at[$commit]=$time
  app_time=$(git -C "$work/app" show -s --format=%ct "$tag")
  leads+=($(( (time - app_time) / 60 )))
done < <(git -C "$work/config" log --reverse --format='%H %ct %s' -- envs/production)

# median <numbers>: the middle one; for an even count, the mean of the two.
median() { printf '%s\n' "$@" | sort -n | awk '{v[NR] = $1} END {print (NR % 2) ? v[(NR + 1) / 2] : (v[NR / 2] + v[NR / 2 + 1]) / 2}'; }
hours() { awk -v m="$1" 'BEGIN {printf "%.1f hours", m / 60}'; }

echo "== the four metrics, for 13 weeks"
echo "deploys: $deploys, $(awk -v d="$deploys" 'BEGIN {printf "%.1f", d / 13}') a week"
echo "lead time for changes, median: $(hours "$(median "${leads[@]}")") (each deploy, in hours: $(for m in "${leads[@]}"; do awk -v m="$m" 'BEGIN {printf "%.1f ", m / 60}'; done | sed 's/ $//'))"
echo "change failure rate: $failed of $deploys deploys reverted, $(awk -v f="$failed" -v d="$deploys" 'BEGIN {printf "%.0f%%", 100 * f / d}')"
echo "time to restore, median: $(median "${restores[@]}") minutes (each failed deploy: ${restores[*]} minutes)"

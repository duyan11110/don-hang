#!/usr/bin/env bash
# Run one script (or --all of them) and store the output under outputs/<tag>/,
# with the parts that differ on every run replaced by "..." — see
# outputs/unstable.regex.
set -euo pipefail
cd "$(dirname "$0")/.."

tag="${TAG:-stage-0}"

capture() {
  local script="${1#./}"
  shift
  # Extra arguments are passed to the script and named in the output file:
  # dr-drill.sh --without-sealing-key -> dr-drill-without-sealing-key.txt.
  local -a args=("$@")
  local suffix=""
  for arg in "${args[@]}"; do suffix="$suffix-${arg#--}"; done
  local out="outputs/$tag/${script%.sh}$suffix.txt"
  mkdir -p "$(dirname "$out")"

  # scripts/terminal/ssh-into-lab.sh and scripts/debug/run-throws-deep.sh talk
  # to the lab box from outside, so they run here; scripts/http/raw-request.sh
  # has no line that sends it into the box, so this sends it.
  local -a command
  case "$script" in
    scripts/terminal/ssh-into-lab.sh | scripts/debug/run-throws-deep.sh)
      command=(bash "$script") ;;
    scripts/release-notes.sh)
      # It takes the version to print; devops.l2.cutting-a-release shows 1.0.0.
      command=(bash "$script" 1.0.0) ;;
    *)
      # A script that says it runs on the host (it needs docker or dotnet
      # itself) is run here, like one that sends itself into the box.
      if grep -q -e 'lab-run.sh' -e '^# Runs on the host' "$script"; then
        command=(bash "$script" "${args[@]}")
      else
        command=(scripts/lab-run.sh "$script")
      fi
      ;;
  esac

  local status=0
  "${command[@]}" > "$out" 2>&1 || status=$?
  if [ "$status" -ne 0 ]; then
    echo "FAILED (exit $status): $script" >&2
    tail -n 30 "$out" | sed 's/^/    /' >&2
    return 1
  fi

  # OpenTofu prints progress lines (Creating..., Still creating... [10s
  # elapsed], Refreshing state...); how many there are and in which order
  # depends on timing, so the devops scripts captured here lose them.
  if is_devops_host "$script"; then
    perl -ni -e 'print unless /^\S+: (?:Still [a-z]+\.\.\. \[.*elapsed\]|(?:Creating|Destroying|Modifying|Reading)\.\.\.|(?:Creation|Destruction|Modifications|Read) complete after .*|Refreshing state\.\.\. .*)$/' "$out"
  fi

  # kubectl pads every table column to its widest value, so a masked Pod name
  # or age would still shift the columns after it. In the output of
  # scripts/k8s/, each run of two or more spaces between words becomes three.
  case "$script" in
    scripts/k8s/*) perl -pi -e 's/(?<=\S) {2,}(?=\S)/   /g' "$out" ;;
  esac

  perl - "$out" <<'MASK'
my ($file) = @ARGV;
open my $rules, '<', 'outputs/unstable.regex' or die "unstable.regex: $!";
my @patterns = grep { /\S/ and not /^#/ } map { chomp; $_ } <$rules>;
close $rules;

open my $in, '<', $file or die "$file: $!";
my @lines = <$in>;
close $in;

open my $written, '>', $file or die "$file: $!";
for my $line (@lines) {
    $line =~ s/$_/.../g for @patterns;
    print {$written} $line;
}
close $written;
MASK

  # Then line the columns up again, now that no value in them changes.
  case "$script" in
    scripts/k8s/*) perl - "$out" <<'ALIGN'
my ($file) = @ARGV;
open my $in, '<', $file or die "$file: $!";
my @lines = map { chomp; $_ } <$in>;
close $in;

# A table is a run of lines with the same number of fields split by 3 spaces.
my @out;
my $i = 0;
while ($i < @lines) {
    my $n = () = split /   /, $lines[$i], -1;
    my $j = $i;
    $j++ while $j < @lines && $n > 1 && (() = split /   /, $lines[$j], -1) == $n;
    $j = $i + 1 if $j == $i;
    my @rows = map { [split /   /, $_, -1] } @lines[$i .. $j - 1];
    my @width;
    for my $row (@rows) {
        for my $c (0 .. $#$row - 1) {
            $width[$c] = length $row->[$c] if length $row->[$c] > ($width[$c] // 0);
        }
    }
    for my $row (@rows) {
        push @out, join '', (map { sprintf '%-*s   ', $width[$_], $row->[$_] } 0 .. $#$row - 1), $row->[-1];
    }
    $i = $j;
}

open my $written, '>', $file or die "$file: $!";
print {$written} "$_\n" for @out;
close $written;
ALIGN
      ;;
  esac

  echo "captured $out"
}

# The scripts of the k8s track need the kind cluster, not the lab, and build
# on each other, so --k8s runs them in the order of the lessons, on a new
# cluster; it leaves the cluster running (scripts/k8s/cluster-down.sh).
k8s_scripts=(
  cluster-up get-nodes apply-web-pod namespaces control-plane
  labels replicaset deployment service service-dns
  deploy-api rolling-update rollback
  configmap secrets deploy configmap-files smoke-test
  health liveness readiness resources
)

# The scripts of devops/iac, gitops and secrets-backup-dr drive OpenTofu,
# kind, Argo CD and the Git server inside donhang-staging from this machine,
# and build on each other: --devops-host runs them here, in the order of the
# lessons. CI has none of that, so --all skips them. tofu-env.sh and
# gitops-render.sh are plumbing they call.
devops_host_scripts=(
  tofu-teardown tofu-first-cluster tofu-plan-apply tofu-state tofu-moved tofu-teardown
  tofu-environments tofu-db tofu-lock tofu-drift
  argocd-install gitops-repo gitops-first-sync gitops-order gitops-deploy
  gitops-self-heal gitops-revert gitops-promote
  sealed-secrets-install seal-secrets rotate-db-password
  "dr-drill --without-sealing-key" dr-drill deploy-verified
)
# From stage-3 the k8s track's lessons of ingress-helm, state-and-storage
# and security-and-policy run on donhang-staging after the scripts above
# (or on donhang, from pvc to reclaim-policy), each building on the one
# before: --k8s-host runs them here, in the order of the lessons, and
# leaves donhang-staging running.
k8s_host_scripts=(
  helm-template helm-release traefik-install ingress gateway gateway-tls
  kustomize-render kustomize-config-repo
  pvc storage-class reclaim-policy statefulset-db headless-dns stateful-staging db-backup
  api-request-checks rbac-role service-accounts cluster-roles security-context pod-security
  network-policy admission-policy
)

is_devops_host() {
  local name
  for name in "${devops_host_scripts[@]}" tofu-env gitops-render; do
    [ "$1" = "scripts/devops/${name%% *}.sh" ] && return 0
  done
  return 1
}

if [ "${1:-}" = "--all" ]; then
  # scripts/lib/ holds helpers other scripts source, not lessons; scripts/k8s/
  # is captured by --k8s.
  for script in $(find scripts git-playground -name '*.sh' ! -path 'scripts/lib/*' ! -path 'scripts/k8s/*' \
                    ! -name 'up.sh' ! -name 'down.sh' ! -name 'dev-secrets.sh' \
                    ! -name 'lab-run.sh' ! -name 'capture-output.sh' | sort); do
    is_devops_host "$script" || capture "$script"
  done
elif [ "${1:-}" = "--k8s" ]; then
  scripts/k8s/cluster-down.sh >/dev/null
  for name in "${k8s_scripts[@]}"; do
    capture "scripts/k8s/$name.sh"
  done
elif [ "${1:-}" = "--devops-host" ]; then
  # The first tofu-teardown removes what an earlier run left (it captures
  # nothing new: the second one, after the modules lesson, overwrites it).
  for entry in "${devops_host_scripts[@]}"; do
    read -r -a words <<< "$entry"
    capture "scripts/devops/${words[0]}.sh" "${words[@]:1}"
  done
elif [ "${1:-}" = "--k8s-host" ]; then
  for name in "${k8s_host_scripts[@]}"; do
    capture "scripts/k8s/$name.sh"
  done
else
  capture "${1:?usage: scripts/capture-output.sh <path to a script> [arguments] | --all | --k8s | --devops-host | --k8s-host}" "${@:2}"
fi

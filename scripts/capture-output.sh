#!/usr/bin/env bash
# Run one script (or --all of them) and store the output under outputs/<tag>/,
# with the parts that differ on every run replaced by "..." — see
# outputs/unstable.regex.
set -euo pipefail
cd "$(dirname "$0")/.."

tag="${TAG:-stage-0}"

capture() {
  local script="${1#./}"
  local out="outputs/$tag/${script%.sh}.txt"
  mkdir -p "$(dirname "$out")"

  case "$script" in
    # These two talk to the lab box from outside, so they run here.
    scripts/terminal/ssh-into-lab.sh | scripts/debug/run-throws-deep.sh)
      bash "$script" > "$out" 2>&1
      ;;
    *)
      if grep -q 'lab-run.sh' "$script"; then
        bash "$script" > "$out" 2>&1
      else
        scripts/lab-run.sh "$script" > "$out" 2>&1
      fi
      ;;
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

  echo "captured $out"
}

if [ "${1:-}" = "--all" ]; then
  for script in $(find scripts git-playground -name '*.sh' \
                    ! -name 'up.sh' ! -name 'down.sh' ! -name 'dev-secrets.sh' \
                    ! -name 'lab-run.sh' ! -name 'capture-output.sh' | sort); do
    capture "$script"
  done
else
  capture "${1:?usage: scripts/capture-output.sh <path to a script> | --all}"
fi

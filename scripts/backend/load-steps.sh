#!/usr/bin/env bash
# Read the product list with 1, 5, 10, 20 and 40 requests in flight and print, per step, reads answered 200 per second, average time, p95 and 503 count.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

url='http://localhost:8080/api/v1/products?limit=20'
per_step=400
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Warm up: connections, the JIT, the database's cache.
for _ in $(seq 20); do curl -sS -o /dev/null "$url"; done

# lesson: backend.l4.load-testing
# Each step sends the same number of reads, keeping N of them in flight at
# all times (curl starts a new one as soon as one ends). For each answer curl
# writes its status and its time; the step's wall clock gives the rate.
step() {
  local n=$1 started ended
  local -a requests=()
  for _ in $(seq "$per_step"); do requests+=(-o /dev/null "$url"); done
  started=$(date +%s.%N)
  curl -sS --parallel --parallel-immediate --parallel-max "$n" -w '%{http_code} %{time_total}\n' "${requests[@]}" > "$tmp/$n"
  ended=$(date +%s.%N)
  # Little's law: requests in flight = answers per second x average time.
  sort -k2 -n "$tmp/$n" | awk -v n="$n" -v wall="$(echo "$ended - $started" | bc -l)" '
    { time[NR] = $2; sum += $2; if ($1 == 200) ok++; else if ($1 == 503) busy++ }
    END {
      avg = sum / NR; p95 = time[int(NR * 0.95 + 0.5)]
      printf "%3d in flight: %6.1f answered 200/s, average %5.1f ms, p95 %5.1f ms, 503: %d, answers/s x average = %.1f\n",
             n, ok / wall, avg * 1000, p95 * 1000, busy, NR / wall * avg
    }'
}

for n in 1 5 10 20 40; do step "$n"; done | tee "$tmp/steps"

echo
awk '
  { n = $1; rate[n] = $4; p95[n] = $11; busy[n] = $14 + 0; product[n] = $NF
    if (product[n] < 0.7 * n || product[n] > 1.3 * n) close_enough = "no" }
  END {
    print "answers/s x average is close to the number in flight at each step: " (close_enough == "" ? "yes" : "no")
    print "p95 at 40 is higher than at 1: " (p95[40] > p95[1] ? "yes" : "no")
    print "200/s at 40 is less than 20 times 200/s at 1: " (rate[40] < 20 * rate[1] ? "yes" : "no")
    print "no 503 up to 20 in flight: " (busy[1] + busy[5] + busy[10] + busy[20] == 0 ? "yes" : "no")
    print "some 503 at 40 in flight: " (busy[40] > 0 ? "yes" : "no")
  }' "$tmp/steps"

#!/usr/bin/env bash
# Build a throwaway repository with a fixed history for the Git lessons.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../scripts/lab-run.sh" "$0" "$@"

repo="${1:-/tmp/git-playground}"
origin="${repo}-origin"
rm -rf "$repo" "$origin"
mkdir -p "$repo"
cd "$repo"

# Fixed author, committer and dates, so that every commit id below is the same
# on every machine and the lessons can quote them.
export GIT_AUTHOR_NAME='Mai Anh'
export GIT_AUTHOR_EMAIL='mai.anh@example.com'
export GIT_COMMITTER_NAME='Mai Anh'
export GIT_COMMITTER_EMAIL='mai.anh@example.com'

save() {  # save <date> <message>
    export GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1"
    git add -A
    git commit --quiet --message "$2"
}

git init --quiet --initial-branch=main
git config user.name 'Mai Anh'
git config user.email 'mai.anh@example.com'

printf 'keyboard 1250000\n' > prices.txt
save '2026-02-02T09:00:00+07:00' 'Add the price list'

cat > total.sh <<'SH'
#!/bin/sh
# Print the total price of everything in the price list.
set -eu
total=0
while read -r name price; do
    total=$((total + price))
done < prices.txt
echo "$total"
SH
cat > test.sh <<'SH'
#!/bin/sh
# Fail unless total.sh agrees with a plain sum of the price list.
set -eu
expected=$(awk '{ sum += $2 } END { print sum }' prices.txt)
actual=$(./total.sh)
if [ "$actual" != "$expected" ]; then
    echo "expected $expected, got $actual"
    exit 1
fi
echo "ok"
SH
chmod +x total.sh test.sh
save '2026-02-03T10:00:00+07:00' 'Add total.sh and a check for it'

printf 'keyboard 1250000\nmouse 450000\n' > prices.txt
save '2026-02-04T11:00:00+07:00' 'Add a second product'

git branch feature/shipping
git branch feature/currency

sed -i 's|^echo "\$total"$|echo $(( (total / 1000000) * 1000000 ))|' total.sh
save '2026-02-05T12:00:00+07:00' 'Round the total down to millions'

sed -i 's|^# Print the total|# Round to millions so the invoice looks tidy.\n# Print the total|' total.sh
save '2026-02-06T13:00:00+07:00' 'Explain the rounding'

cat > README.md <<'MD'
# Price list

A tiny script that adds up a price list.

## Files

- prices.txt is the price list, one product per line.
- total.sh prints the total.
- test.sh checks the total against a plain sum.

## Running it

Run ./total.sh from this folder.
Prices are in đồng, written as whole numbers.
MD
save '2026-02-07T14:00:00+07:00' 'Add a README'

git switch --quiet feature/shipping
cat > shipping.sh <<'SH'
#!/bin/sh
# Print the shipping fee for a given order total.
set -eu
total="$1"
echo 30000
SH
chmod +x shipping.sh
save '2026-02-08T09:00:00+07:00' 'Add shipping.sh'
sed -i 's|^echo 30000$|if [ "$total" -ge 2000000 ]; then echo 0; else echo 30000; fi|' shipping.sh
save '2026-02-08T10:00:00+07:00' 'Charge no shipping over two million'

git switch --quiet feature/currency
sed -i 's|^echo "\$total"$|echo "$total đồng"|' total.sh
save '2026-02-09T09:00:00+07:00' 'Print the total in đồng'

git switch --quiet main

# A second repository to play the part of the server.
git clone --quiet --bare "$repo" "$origin"
git remote add origin "$origin"
git fetch --quiet origin
git branch --set-upstream-to=origin/main main >/dev/null

echo "built $repo with $(git rev-list --count main) commits on main"

#!/usr/bin/env bash
# Standard output, standard error, pipes and redirects.
set -euo pipefail
# Everything below runs inside the lab box; this line puts it there.
[ -f /.dockerenv ] || exec "$(dirname "$0")/../lab-run.sh" "$0" "$@"

cd /tmp
printf 'a\nb\na\nc\na\nb\n' > letters.txt

echo "how many of each line:"
sort letters.txt | uniq -c | sort -rn

echo
echo "how many lines contain an a:"
grep -c a letters.txt

echo
echo "this line goes to standard output"
echo "this line goes to standard error" >&2

echo
ls /nowhere 2> errors.txt || echo "the command failed; its message went to errors.txt:"
cat errors.txt

echo
printf 'first\n' > out.txt
printf 'second\n' >> out.txt
cat out.txt

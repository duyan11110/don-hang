#!/usr/bin/env bash
# How far each dependency of DonHang.App reaches: the number of Dart files under lib/ that import it, most first.
# Runs on the host: it only reads DonHang.App/pubspec.yaml and DonHang.App/lib/.
set -euo pipefail
cd "$(dirname "$0")/../../DonHang.App"

# lesson: frontend.l4.library-reach
# The packages under `dependencies:` in pubspec.yaml (not dev_dependencies),
# each marked when it comes with the Flutter SDK rather than from pub.dev.
packages=$(awk '/^dependencies:/ { on = 1; next } /^[^ #]/ { on = 0 }
  on && /^  [a-z0-9_]+:/ { name = $1; sub(":", "", name); print name }' pubspec.yaml)
sdk=$(awk '/^dependencies:/ { on = 1; next } /^[^ #]/ { on = 0 }
  on && /^  [a-z0-9_]+:/ { name = $1; sub(":", "", name) } on && /^    sdk: flutter/ { print name }' pubspec.yaml)

# lesson: frontend.l4.library-reach
# For each package, the files under lib/ with an import or export line of
# package:<name>/, leaving out lib/l10n/, which gen-l10n writes. Replacing
# a package means touching every one of these files.
echo "Files under lib/ (without lib/l10n/) that import each dependency:"
for package in $packages; do
  files=$(grep -rlE "^(import|export) +'package:$package/" lib --include='*.dart' | grep -v '^lib/l10n/' | LC_ALL=C sort || true)
  count=$(grep -c . <<< "$files" || true)
  label=$package
  grep -qx "$package" <<< "$sdk" && label="$package (Flutter SDK)"
  line=$(printf '%3d  %s' "$count" "$label")
  if [ "$count" -gt 0 ] && [ "$count" -le 3 ]; then line="$line: $(paste -sd ' ' <<< "$files")"; fi
  echo "$line"
done | LC_ALL=C sort -k1,1nr -k2,2

#!/usr/bin/env bash
# Make drift by hand (a label on staging's namespace donhang), find it with plan, -refresh-only and -detailed-exitcode, then let apply undo it.
# Runs on the host: OpenTofu and kubectl talk to donhang-staging from here (after scripts/devops/tofu-environments.sh).
set -euo pipefail
cd "$(dirname "$0")/../.."
tofu_platform() { scripts/devops/tofu-env.sh staging platform "$@"; }

# lesson: devops.l3.configuration-drift
# A change made outside OpenTofu: nothing happens until someone plans.
echo "== kubectl label namespace donhang owner=by-hand"
kubectl --context kind-donhang-staging label namespace donhang owner=by-hand
echo

# plan refreshes first, so the label shows up as something it would undo.
# -detailed-exitcode: 2 when the plan has changes, 0 when it has none.
echo "== tofu plan -detailed-exitcode"
status=0
tofu_platform plan -detailed-exitcode -no-color > "${TMPDIR:-/tmp}/drift-plan.txt" || status=$?
sed -n '/^  # /,/^Plan:/p' "${TMPDIR:-/tmp}/drift-plan.txt"
rm -f "${TMPDIR:-/tmp}/drift-plan.txt"
echo "exit code: $status"
echo

# lesson: devops.l3.configuration-drift
# -refresh-only lists only what changed outside OpenTofu.
echo "== tofu plan -refresh-only"
tofu_platform plan -refresh-only -no-color | sed -n '/^  # /,/^    }$/p' 
echo

# The files do not have the label, so apply removes it. Were the label right,
# the fix would be to add it to deploy/tofu/modules/donhang-platform instead.
echo "== tofu apply"
tofu_platform apply -auto-approve -no-color | grep -e '^Apply complete'
echo "labels now: $(kubectl --context kind-donhang-staging get namespace donhang -o jsonpath='{.metadata.labels}')"
status=$(tofu_platform plan -detailed-exitcode -no-color >/dev/null 2>&1; echo $?)
echo "tofu plan -detailed-exitcode: exit code $status"

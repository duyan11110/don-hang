#!/usr/bin/env bash
# Look at OpenTofu's state for donhang-iac: what it records, a credential in plain text, a removed block planned for destruction, a lost state, and a saved plan gone stale.
# Runs on the host: OpenTofu drives Docker from here (after scripts/devops/tofu-plan-apply.sh). It puts every file back as it found it.
set -euo pipefail
cd "$(dirname "$0")/../../deploy/tofu/lessons/first-cluster"
show() { echo "\$ $*"; "$@"; }

# lesson: devops.l3.tofu-state
# After apply, the state maps each resource address to the real object and
# the attributes read back from it, in terraform.tfstate next to main.tf.
show tofu state list
echo
# The client key that administers the cluster sits in it as plain text
# (only its first line is printed here).
echo '$ grep -o '"'"'"client_key": *"-----BEGIN [A-Z ]*-----'"'"' terraform.tfstate'
grep -o '"client_key": *"-----BEGIN [A-Z ]*-----' terraform.tfstate
echo

# lesson: devops.l3.tofu-state
# A block removed from the files, still in the state: planned for destruction.
echo "== main.tf without its resource block"
cp main.tf main.tf.orig
trap 'mv main.tf.orig main.tf' EXIT
perl -0pi -e 's/\n# lesson: devops\.l3\.plan-and-apply\n.*//s' main.tf
tofu plan -no-color | grep -e '^  # ' -e '^Plan:'
mv main.tf.orig main.tf
trap - EXIT
echo

# lesson: devops.l3.tofu-state
# Without its state OpenTofu knows of no cluster: it plans to create one,
# and creating it fails, because a cluster with that name already runs.
echo "== terraform.tfstate moved away"
mv terraform.tfstate state.saved
trap 'mv state.saved terraform.tfstate' EXIT
tofu plan -out=stale.tfplan -no-color | grep -e '^  # ' -e '^Plan:'
tofu apply -auto-approve -no-color 2>&1 | grep -e '^Error' || true
mv state.saved terraform.tfstate
trap - EXIT
echo

# The plan saved without the state no longer fits the state now in place.
echo "== the state is back; apply the plan saved without it"
show tofu apply -no-color stale.tfplan || echo "(exit $?)"
rm -f stale.tfplan

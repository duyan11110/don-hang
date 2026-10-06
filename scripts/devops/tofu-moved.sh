#!/usr/bin/env bash
# Move donhang-iac into the kind-cluster module: plan without and with the moved block, then apply the move and list the new address.
# Runs on the host: OpenTofu drives Docker from here (after scripts/devops/tofu-state.sh). The state moves from lessons/first-cluster to lessons/moved-into-module.
set -euo pipefail
cd "$(dirname "$0")/../../deploy/tofu/lessons/moved-into-module"
show() { echo "\$ $*"; "$@"; }

# The cluster's state comes along from first-cluster, whose folder then
# describes nothing.
if [ -f ../first-cluster/terraform.tfstate ]; then
  mv ../first-cluster/terraform.tfstate terraform.tfstate
  rm -f ../first-cluster/terraform.tfstate.backup
fi
tofu init -input=false -no-color >/dev/null

# lesson: devops.l3.tofu-modules
# Without the moved block, the old address is gone from the files and the
# new one is not in the state: destroy one cluster, create another.
echo "== without the moved block"
cp main.tf main.tf.orig
trap 'mv main.tf.orig main.tf' EXIT
perl -0pi -e 's/\n# lesson: devops\.l3\.tofu-modules\n.*//s' main.tf
tofu plan -no-color | grep -e '^  # ' -e '^Plan:'
mv main.tf.orig main.tf
trap - EXIT
echo

echo "== with it"
tofu plan -no-color | grep -e '^  # ' -e '^Plan:'
echo
show tofu apply -auto-approve -no-color
echo
show tofu state list

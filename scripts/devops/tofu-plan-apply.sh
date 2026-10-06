#!/usr/bin/env bash
# Save a plan and apply exactly it, see that a changed node image plans to replace the whole cluster, and that applying unchanged files changes nothing.
# Runs on the host: OpenTofu drives Docker from here (after scripts/devops/tofu-first-cluster.sh).
set -euo pipefail
cd "$(dirname "$0")/../../deploy/tofu/lessons/first-cluster"
show() { echo "\$ $*"; "$@"; }

# lesson: devops.l3.plan-and-apply
# Edit the node image, as someone moving to another Kubernetes version
# would, and plan: the cluster cannot change its image in place, so the plan
# replaces it (-/+). The edit is undone when the script ends.
cp main.tf main.tf.orig
trap 'mv main.tf.orig main.tf' EXIT
perl -pi -e 's#kindest/node:v1\.34\.11\@sha256:[0-9a-f]+#kindest/node:v1.33.7\@sha256:d26ef333bdb2cbe9862a0f7c3803ecc7b4303d8cea8e814b481b09949d353040#' main.tf
diff main.tf.orig main.tf || true
echo
# (The plan lists every attribute, the cluster's credentials too; only the
# lines that say what would happen and why are kept here.)
echo '$ tofu plan'
tofu plan -no-color | grep -e '^  # ' -e 'forces replacement' -e '^Plan:'
mv main.tf.orig main.tf
trap - EXIT
echo

# lesson: devops.l3.plan-and-apply
# With the file as committed: save the plan, then apply that file. apply
# asks nothing and takes exactly the saved actions, here none.
show tofu plan -out=first-cluster.tfplan -no-color
echo
show tofu apply -no-color first-cluster.tfplan
rm -f first-cluster.tfplan
echo
# A second apply of unchanged files: the cluster already matches them.
echo '$ tofu apply   (answered: yes)'
echo yes | tofu apply -no-color

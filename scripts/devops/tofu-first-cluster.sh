#!/usr/bin/env bash
# Create the kind cluster donhang-iac with OpenTofu from deploy/tofu/lessons/first-cluster: init, fmt -check, validate, then apply answered with yes.
# Runs on the host: OpenTofu drives Docker from here, as kind does in scripts/k8s/cluster-up.sh.
set -euo pipefail
cd "$(dirname "$0")/../../deploy/tofu/lessons/first-cluster"
show() { echo "\$ $*"; "$@"; }

# lesson: devops.l3.opentofu-resources
# init downloads the provider into .terraform/; the version comes from the
# committed .terraform.lock.hcl. Start from the folder as Git has it.
rm -rf .terraform
show tofu init -input=false -no-color
echo
# Formatting and references are checked without contacting Docker.
show tofu fmt -check
show tofu validate -no-color
echo

# lesson: devops.l3.plan-and-apply
# Without a plan file, apply plans first, prints the plan, and acts only
# after "yes" (typed here by echo).
echo '$ tofu apply   (answered: yes)'
context=$(kubectl config current-context 2>/dev/null || true)
echo yes | tofu apply -no-color
# The kind provider made donhang-iac kubectl's current context; switch back,
# so that scripts/k8s/ keep talking to the cluster donhang.
[ -n "$context" ] && kubectl config use-context "$context" >/dev/null
echo
kind get clusters

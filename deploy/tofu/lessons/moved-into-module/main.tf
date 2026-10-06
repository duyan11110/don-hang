# The cluster donhang-iac of lessons/first-cluster, now declared through the
# kind-cluster module. scripts/devops/tofu-moved.sh brings first-cluster's
# state here; the moved block keeps the plan from replacing the cluster.
terraform {
  required_version = "~> 1.10.0"
}

module "cluster" {
  source  = "../../modules/kind-cluster"
  name    = "donhang-iac"
  workers = 0
}

# lesson: devops.l3.tofu-modules
# The same cluster under its new address. Without this block the plan would
# destroy kind_cluster.this and create module.cluster.kind_cluster.this.
moved {
  from = kind_cluster.this
  to   = module.cluster.kind_cluster.this
}

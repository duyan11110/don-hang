# lesson: devops.l3.one-state-per-environment
# Staging's cluster: the kind-cluster module with one node, where Argo CD,
# the Git server and the whole backend run. A folder of its own, so a state
# of its own: nothing applied here can touch production.
terraform {
  required_version = "~> 1.10.0"
}

module "cluster" {
  source  = "../../../modules/kind-cluster"
  name    = "donhang-staging"
  workers = 0
}

# The platform layer reads these through terraform_remote_state. The
# certificates are marked sensitive only to keep them out of apply's output.
output "endpoint" {
  value = module.cluster.endpoint
}

output "cluster_ca_certificate" {
  value     = module.cluster.cluster_ca_certificate
  sensitive = true
}

output "client_certificate" {
  value     = module.cluster.client_certificate
  sensitive = true
}

output "client_key" {
  value     = module.cluster.client_key
  sensitive = true
}

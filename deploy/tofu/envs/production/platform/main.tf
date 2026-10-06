# Production's platform layer: what the cluster needs before Argo CD deploys
# anything, from the donhang-platform module. It is a separate configuration
# from the cluster layer because the Kubernetes provider below can connect
# only to a cluster that already exists.
terraform {
  required_version = "~> 1.10.0"
}

# lesson: devops.l3.one-state-per-environment
# The cluster layer's outputs, read from its own state in donhang_tofu
# (the pg backend takes the connection string from PG_CONN_STR here too).
data "terraform_remote_state" "cluster" {
  backend = "pg"
  config = {
    schema_name = "production_cluster"
  }
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.cluster.outputs.endpoint
  cluster_ca_certificate = data.terraform_remote_state.cluster.outputs.cluster_ca_certificate
  client_certificate     = data.terraform_remote_state.cluster.outputs.client_certificate
  client_key             = data.terraform_remote_state.cluster.outputs.client_key
}

# lesson: devops.l3.configuration-drift
# The namespace donhang and the sealing key, from files outside Git: the key
# pair scripts/dev-secrets.sh creates in secrets/ at the repository's root.
module "platform" {
  source              = "../../../modules/donhang-platform"
  sealing_certificate = file("${path.root}/../../../../../secrets/sealing.crt")
  sealing_private_key = file("${path.root}/../../../../../secrets/sealing.key")
}

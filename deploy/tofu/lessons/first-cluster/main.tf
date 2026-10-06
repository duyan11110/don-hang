# lesson: devops.l3.opentofu-resources
# One kind cluster, donhang-iac, described for OpenTofu. Every .tf file in
# this folder is one configuration; this is the only one.
terraform {
  required_version = "~> 1.10.0"
  required_providers {
    # The provider that knows how to create kind clusters through Docker.
    kind = {
      source  = "tehcyx/kind"
      version = "0.11.0"
    }
  }
}

# lesson: devops.l3.plan-and-apply
# One resource: a cluster of type kind_cluster, named "this" inside this
# configuration. The node image is the one deploy/k8s/kind-config.yaml pins,
# by the same digest; changing it replaces the whole cluster.
resource "kind_cluster" "this" {
  name           = "donhang-iac"
  node_image     = "kindest/node:v1.34.11@sha256:44e222ee2132dab25ff87301682f89eb82c7880ea3a1bf543bfe9708fd08d67d"
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"
    node {
      role = "control-plane"
    }
  }
}

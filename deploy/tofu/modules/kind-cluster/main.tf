# lesson: devops.l3.tofu-modules
# One kind cluster: one control-plane node and var.workers worker nodes. The
# node image is not a variable: every caller, so every environment, runs the
# same Kubernetes version, the one deploy/k8s/kind-config.yaml pins.
terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.11.0"
    }
  }
}

resource "kind_cluster" "this" {
  name           = var.name
  node_image     = "kindest/node:v1.34.11@sha256:44e222ee2132dab25ff87301682f89eb82c7880ea3a1bf543bfe9708fd08d67d"
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"
    node {
      role = "control-plane"

      # lesson: k8s.l2.ingress
      # Each entry publishes one port of this node on this machine, on
      # 127.0.0.1 only; a request to the host port reaches the node port.
      # kind sets this when it creates the node: a change replaces the cluster.
      dynamic "extra_port_mappings" {
        for_each = var.published_ports
        content {
          container_port = extra_port_mappings.value.node_port
          host_port      = extra_port_mappings.value.host_port
          listen_address = "127.0.0.1"
        }
      }
    }
    # One more node block per worker; with workers = 0 there is none.
    dynamic "node" {
      for_each = range(var.workers)
      content {
        role = "worker"
      }
    }
  }
}

# What every environment's cluster needs before anything is deployed to it:
# the namespace donhang, and the key that opens the SealedSecrets in the
# config repository. The api, the database and their Secrets are not here:
# Argo CD deploys them from the config repository.
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.3.0"
    }
  }
}

# lesson: devops.l3.configuration-drift
# The namespace's labels are part of this resource: one added by hand with
# kubectl label shows up in the next plan as a change OpenTofu would undo.
resource "kubernetes_namespace_v1" "donhang" {
  metadata {
    name = "donhang"
  }
}

# lesson: devops.l3.sealed-secrets
# The sealing key pair from secrets/, installed before the Sealed Secrets
# controller starts. The label tells the controller to use it; the controller
# runs with --key-renew-period=0, so it creates no key of its own beside it.
resource "kubernetes_secret_v1" "sealing_key" {
  metadata {
    name      = "sealing-key"
    namespace = "kube-system"
    labels = {
      "sealedsecrets.bitnami.com/sealed-secrets-key" = "active"
    }
  }
  type = "kubernetes.io/tls"
  data = {
    "tls.crt" = var.sealing_certificate
    "tls.key" = var.sealing_private_key
  }
}

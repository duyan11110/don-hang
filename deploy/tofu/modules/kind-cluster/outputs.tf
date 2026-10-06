# lesson: devops.l3.tofu-modules
# What the module hands back: where the cluster's API server listens and the
# credentials to talk to it. The caller reads them as module.<name>.endpoint
# and so on; sensitive values are not printed in plans or after apply.
output "endpoint" {
  description = "Address of the cluster's API server, as seen from this machine."
  value       = kind_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  value = kind_cluster.this.cluster_ca_certificate
}

output "client_certificate" {
  value = kind_cluster.this.client_certificate
}

output "client_key" {
  value     = kind_cluster.this.client_key
  sensitive = true
}

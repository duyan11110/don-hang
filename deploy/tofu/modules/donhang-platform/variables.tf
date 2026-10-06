# The sealing key pair scripts/dev-secrets.sh creates in secrets/; the
# environment's platform layer reads both files and passes them in.
variable "sealing_certificate" {
  description = "Certificate of the sealing key pair (PEM), from secrets/sealing.crt."
  type        = string
}

variable "sealing_private_key" {
  description = "Private key of the sealing key pair (PEM), from secrets/sealing.key."
  type        = string
  sensitive   = true
}

# From stage-3: the Pod Security level enforced in the namespace donhang.
variable "pod_security_enforce" {
  description = "Pod Security level to enforce in donhang: privileged, baseline or restricted."
  type        = string

  validation {
    condition     = contains(["privileged", "baseline", "restricted"], var.pod_security_enforce)
    error_message = "pod_security_enforce must be privileged, baseline or restricted."
  }
}

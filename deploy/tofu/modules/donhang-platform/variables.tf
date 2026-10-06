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

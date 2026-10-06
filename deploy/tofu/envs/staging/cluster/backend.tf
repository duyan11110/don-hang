# Where this layer keeps its state: a table in the schema staging_cluster of
# the database donhang_tofu, in Compose's PostgreSQL. The connection string
# comes from PG_CONN_STR (scripts/devops/tofu-env.sh builds it from .env).
# The state is encrypted with a key derived from TOFU_STATE_PASSPHRASE before
# it is written, and plans saved with -out are encrypted too.
# lesson: devops.l3.remote-state-and-locking
terraform {
  backend "pg" {
    schema_name = "staging_cluster"
  }

  encryption {
    key_provider "pbkdf2" "passphrase" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "state" {
      keys = key_provider.pbkdf2.passphrase
    }
    state {
      method   = method.aes_gcm.state
      enforced = true
    }
    plan {
      method   = method.aes_gcm.state
      enforced = true
    }
  }
}

variable "state_passphrase" {
  description = "TOFU_STATE_PASSPHRASE from .env, passed as TF_VAR_state_passphrase."
  type        = string
  sensitive   = true
}

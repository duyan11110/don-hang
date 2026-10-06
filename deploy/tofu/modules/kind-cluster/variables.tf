# lesson: devops.l3.tofu-modules
# The module's parameters: every caller gives a name and may give a number
# of workers. A variable with no default must be given.
variable "name" {
  description = "Name of the kind cluster; its kubectl context is kind-<name>."
  type        = string
}

variable "workers" {
  description = "Number of worker nodes beside the one control-plane node."
  type        = number
  default     = 0
}

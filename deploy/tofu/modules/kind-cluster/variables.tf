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

# From stage-3: ports of the control-plane node published on this machine,
# for an ingress controller listening on node ports. None by default.
variable "published_ports" {
  description = "Node ports of the control-plane node to publish on 127.0.0.1, each with its host port."
  type = list(object({
    node_port = number
    host_port = number
  }))
  default = []
}

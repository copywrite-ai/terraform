variable "remote_ip" {
  description = "Target Cloud AnolisOS VM IP address"
  type        = string
  default     = "106.14.26.23"
}

variable "ssh_user" {
  description = "SSH username for the remote host"
  type        = string
  default     = "root"
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "host_data_path" {
  description = "Remote host path for volume mounting"
  type        = string
  default     = "/root/terraform/data"
}

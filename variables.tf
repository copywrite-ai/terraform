variable "remote_ip" {
  description = "Target OrbStack VM IP address"
  type        = string
  default     = "192.168.x.x" # 使用您的 OrbStack VM IP
}

variable "ssh_user" {
  description = "SSH username for the remote host"
  type        = string
  default     = "your-username"
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "host_data_path" {
  description = "Absolute Mac path for OrbStack volume mounting"
  type        = string
  default     = "/Users/your-username/path/to/project/data"
}

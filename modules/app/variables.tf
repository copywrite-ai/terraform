variable "database_ip" {
  type        = string
  description = "从外部传入的数据库 IP"
}

variable "remote_host" {
  type = string
}

variable "ssh_user" {
  type = string
}

variable "ssh_private_key_path" {
  type = string
}

variable "host_data_path" {
  type = string
}

variable "sql_backup_path" {
  type = string
}

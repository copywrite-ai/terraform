################################################################################
# mydumper 数据恢复任务模块
################################################################################

variable "database_ip" {
  type        = string
  description = "目标数据库的 IP 地址（通过依赖上游模块输出传入）"
}

variable "remote_host" {
  type        = string
  description = "远程主机 IP"
}

variable "ssh_user" {
  type        = string
  description = "SSH 用户名"
}

variable "ssh_private_key_path" {
  type        = string
  description = "SSH 私钥路径"
}

variable "host_data_path" {
  type        = string
  description = "远程主机上的数据目录"
}

variable "sql_backup_path" {
  type        = string
  description = "本地 SQL 备份压缩包路径"
}

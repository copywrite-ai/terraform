################################################################################
# 变量定义
################################################################################

# 主机配置
variable "hosts" {
  description = "远程主机配置"
  type = map(object({
    ip       = string
    user     = string
    key_path = string
    data_dir = string
  }))
}

# SSH 私钥路径（全局默认）
variable "ssh_key_path" {
  description = "SSH 私钥路径"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

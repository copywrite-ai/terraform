################################################################################
# 全局变量定义 - 多主机 Docker 管理架构
################################################################################

# 主机配置列表
variable "hosts" {
  description = "远程主机配置映射"
  type = map(object({
    ip                   = string
    ssh_user             = string
    ssh_private_key_path = string
    data_path            = string
  }))
  default = {
    host_a = {
      ip                   = "106.14.26.23"
      ssh_user             = "root"
      ssh_private_key_path = "~/.ssh/id_ed25519"
      data_path            = "/root/terraform/data"
    }
    host_b = {
      ip                   = ""  # 待填写
      ssh_user             = "root"
      ssh_private_key_path = "~/.ssh/id_ed25519"
      data_path            = "/root/terraform/data"
    }
    host_c = {
      ip                   = ""  # 待填写
      ssh_user             = "root"
      ssh_private_key_path = "~/.ssh/id_ed25519"
      data_path            = "/root/terraform/data"
    }
  }
}

# 当前激活的主机（用于部署服务时选择节点）
variable "active_host" {
  description = "当前部署目标主机的 key（对应 hosts 中的 key）"
  type        = string
  default     = "host_a"
}

# 服务间通讯的私网 IP（先 hardcode）
variable "mysql_private_ip" {
  description = "MySQL 服务的私网 IP 地址"
  type        = string
  default     = "172.24.216.194"
}

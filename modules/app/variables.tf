variable "app_name" {
  type = string
}

variable "image" {
  type        = string
  description = "Docker 镜像完整路径 (例如: harbor.local/library/app:v1)"
  
  # 友好提示：允许 [域名/项目/名称:标签] 或 [名称:标签]
  validation {
    condition     = can(regex("^([^/]+/)*([^/]+):([^/]+)$", var.image))
    error_message = "错误: 镜像格式建议包含 [域名]/[项目]/[名称]:[标签]，或至少包含 [名称]:[标签]。"
  }
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

variable "env" {
  type    = list(string)
  default = []
}

variable "ports" {
  type = list(object({
    internal = number
    external = number
  }))
  default = []
}

# 配置文件映射: 本地路径 => 远程/容器内路径
variable "config_files" {
  type    = map(string)
  default = {}
}

variable "healthcheck" {
  type = object({
    test         = list(string)
    interval     = string
    timeout      = string
    retries      = number
    start_period = string
  })
  default = null
}

variable "data_volumes" {
  type    = map(string)
  default = {}
}

variable "wait" {
  type    = bool
  default = true
}

variable "wait_timeout" {
  type    = number
  default = 60
}

variable "command" {
  type    = list(string)
  default = null
}

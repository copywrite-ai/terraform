variable "app_name" {
  type = string
}

variable "image" {
  type = string
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

################################################################################
# Docker App Module - 变量定义
################################################################################

# ============================================================================
# 必需参数
# ============================================================================

variable "app_name" {
  description = "应用名称（容器名）"
  type        = string
}

variable "image" {
  description = "Docker 镜像"
  type        = string
}

variable "host" {
  description = "目标主机配置"
  type = object({
    ip       = string
    user     = string
    key_path = string
    data_dir = string
  })
}

# ============================================================================
# 任务类型
# ============================================================================

variable "is_oneshot" {
  description = "是否为一次性任务（每次 apply 重新执行）"
  type        = bool
  default     = false
}

# ============================================================================
# 依赖
# ============================================================================

variable "depends_on_ready" {
  description = "上游模块的 ready 输出（用于建立依赖）"
  type        = string
  default     = ""
}

# ============================================================================
# 配置分发
# ============================================================================

variable "config_files" {
  description = "配置文件映射 {本地路径 = 远程路径}"
  type        = map(string)
  default     = {}
}

variable "archive" {
  description = "压缩包分发配置（单个）"
  type = object({
    source      = string  # 本地压缩包路径
    destination = string  # 远程解压目录
    type        = string  # tar.gz 或 zip
  })
  default = null
}

# ============================================================================
# 容器配置
# ============================================================================

variable "env" {
  description = "环境变量列表"
  type        = list(string)
  default     = []
}

variable "command" {
  description = "容器启动命令"
  type        = list(string)
  default     = null
}

variable "ports" {
  description = "端口映射"
  type = list(object({
    internal = number
    external = number
  }))
  default = []
}

variable "volumes" {
  description = "数据卷映射 {宿主机路径 = 容器路径}"
  type        = map(string)
  default     = {}
}

variable "network_mode" {
  description = "网络模式"
  type        = string
  default     = "bridge"
}

variable "privileged" {
  description = "是否特权模式"
  type        = bool
  default     = false
}

variable "restart" {
  description = "重启策略（常驻服务）"
  type        = string
  default     = "unless-stopped"
}

variable "ulimits" {
  description = "ulimit 资源限制配置"
  type = list(object({
    name = string
    hard = number
    soft = number
  }))
  default = []
}

# ============================================================================
# 健康检查
# ============================================================================

variable "healthcheck" {
  description = "健康检查配置"
  type = object({
    test         = list(string)
    interval     = string
    timeout      = string
    retries      = number
    start_period = optional(string, "0s")
  })
  default = null
}

variable "health_check_retries" {
  description = "等待健康检查的最大重试次数"
  type        = number
  default     = 30
}

variable "health_check_interval" {
  description = "健康检查重试间隔（秒）"
  type        = number
  default     = 2
}

variable "wait_timeout" {
  description = "容器启动等待超时（秒）"
  type        = number
  default     = 60
}

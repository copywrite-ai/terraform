################################################################################
# 多主机 Docker 管理架构 - 主编排文件
################################################################################
# 
# 架构特点：
# 1. 支持多台远程主机，通过 SSH 管理 Docker 容器
# 2. 每个服务对应一个 module，支持常驻服务和一次性任务
# 3. 模块间通过 output 引用建立隐式依赖，确保上游服务健康后才启动下游
#
################################################################################

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4.0"
    }
  }
}

# 获取当前激活主机的配置
locals {
  current_host = var.hosts[var.active_host]
}

################################################################################
# Docker Provider - 通过 SSH 连接远程主机
################################################################################

provider "docker" {
  host = "ssh://${local.current_host.ssh_user}@${local.current_host.ip}"
}

################################################################################
# 数据准备
################################################################################

# 准备 SQL 备份压缩包 (高性能传输)
data "archive_file" "sql_backup" {
  type        = "zip"
  source_dir  = "${path.module}/data/host_data"
  output_path = "${path.module}/data/host_data.zip"
}

################################################################################
# 服务部署
################################################################################

# ========== MySQL 数据库服务（常驻型，带健康检查） ==========
module "mysql" {
  source = "./modules/db"

  remote_host          = local.current_host.ip
  ssh_user             = local.current_host.ssh_user
  ssh_private_key_path = local.current_host.ssh_private_key_path
  host_data_path       = local.current_host.data_path

  # 配置文件映射
  config_files = {
    abspath("${path.module}/my.cnf")    = "/home/${local.current_host.ssh_user}/mysql/conf/my.cnf"
    abspath("${path.module}/mysql.env") = "/home/${local.current_host.ssh_user}/mysql/env/mysql.env"
  }

  # 数据卷映射
  data_volumes = {
    "${local.current_host.data_path}/mysql" = "/var/lib/mysql"
    "${local.current_host.data_path}"       = "/backups"
  }
}

# ========== 数据库迁移任务（一次性任务，依赖 MySQL 健康） ==========
module "mydumper_restore" {
  source = "./modules/app"

  # 【核心依赖】通过引用 mysql 模块的输出，强制等待 MySQL 健康后才启动
  # Terraform 会自动推断依赖关系：mydumper_restore -> mysql
  database_ip = module.mysql.db_private_ip

  remote_host          = local.current_host.ip
  ssh_user             = local.current_host.ssh_user
  ssh_private_key_path = local.current_host.ssh_private_key_path
  host_data_path       = local.current_host.data_path

  sql_backup_path = data.archive_file.sql_backup.output_path
}

################################################################################
# 输出信息
################################################################################

output "active_host" {
  value       = var.active_host
  description = "当前部署的目标主机"
}

output "mysql_container_id" {
  value       = module.mysql.container_id
  description = "MySQL 容器 ID"
}

output "mysql_private_ip" {
  value       = module.mysql.db_private_ip
  description = "MySQL 服务的私网 IP"
}

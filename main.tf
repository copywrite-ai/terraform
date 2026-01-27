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

# 准备 SQL 备份压缩包 (高性能传输)
data "archive_file" "sql_backup" {
  type        = "zip"
  source_dir  = "${path.module}/data/host_data"
  output_path = "${path.module}/data/host_data.zip"
}

provider "docker" {
  host = "ssh://${var.ssh_user}@${var.remote_ip}"
}

# 调用数据库模块
module "my_db" {
  source = "./modules/db"

  remote_host          = var.remote_ip
  ssh_user             = var.ssh_user
  ssh_private_key_path = var.ssh_private_key_path
  host_data_path       = var.host_data_path

  # 优雅：本地路径 => 容器内路径
  config_files = {
    abspath("${path.module}/my.cnf")    = "/home/${var.ssh_user}/mysql/conf/my.cnf"
    abspath("${path.module}/mysql.env") = "/home/${var.ssh_user}/mysql/env/mysql.env"
  }

  # 挂载备份目录
  data_volumes = {
    "${var.host_data_path}/mysql" = "/var/lib/mysql"
    "${var.host_data_path}"       = "/backups"
  }
}

# 调用应用模块
module "my_app" {
  source = "./modules/app"

  # 【核心点】直接把 db 模块的输出赋值给 app 模块的变量
  database_ip = module.my_db.db_private_ip

  remote_host          = var.remote_ip
  ssh_user             = var.ssh_user
  ssh_private_key_path = var.ssh_private_key_path
  host_data_path       = var.host_data_path
  
  sql_backup_path      = data.archive_file.sql_backup.output_path
}

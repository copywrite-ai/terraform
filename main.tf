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
  }
}

provider "docker" {
  # 使用 OrbStack 静态 IP 绕过本地机器名代理 (适配 Docker-in-Docker 运行环境)
  host = "ssh://${var.ssh_user}@${var.remote_ip}"
}

# 使用模块定义 MySQL
module "mysql" {
  source = "./modules/app"

  app_name             = "mysql"
  image                = "docker.1ms.run/library/mysql:8.0.32" # ARM64 compatible
  remote_host          = var.remote_ip
  ssh_user             = var.ssh_user
  ssh_private_key_path = var.ssh_private_key_path

  env = [
    "MYSQL_ROOT_PASSWORD=",
    "MYSQL_ALLOW_EMPTY_PASSWORD=yes",
    "MYSQL_MAX_CONNECTIONS=2000"
  ]

  ports = [{ internal = 3306, external = 3306 }]

  # 优雅：本地路径 => 容器内路径
  config_files = {
    abspath("${path.module}/my.cnf")    = "/home/${var.ssh_user}/mysql/conf/my.cnf"
    abspath("${path.module}/mysql.env") = "/home/${var.ssh_user}/mysql/env/mysql.env"
  }

  # 挂载备份目录 (使用 Mac 绝对路径以便 OrbStack 镜像挂载)
  data_volumes = {
    "${var.host_data_path}/mysql" = "/var/lib/mysql"
    "${var.host_data_path}"       = "/backups"
  }

  healthcheck = {
    test         = ["CMD", "mysqladmin", "ping", "-h", "localhost"]
    interval     = "5s"
    timeout      = "10s"
    retries      = 30
    start_period = "60s"
  }
}

# 备份工具 Mydumper
module "migration" {
  source = "./modules/app"

  app_name             = "migration"
  image                = "docker.1ms.run/mydumper/mydumper:latest"
  remote_host          = var.remote_ip
  ssh_user             = var.ssh_user
  ssh_private_key_path = var.ssh_private_key_path

  # 共享备份目录 (映射到 Mac 宿主机的 ./data)
  data_volumes = {
    "${var.host_data_path}" = "/backups"
  }

  # 让 mydumper 保持运行状态，方便我们进入执行导出命令
  command = ["sh", "-c", "while true; do sleep 1000; done"]
  wait    = false
}

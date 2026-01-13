terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
  }
}

variable "remote_ip" {
  default = "192.168.1.100"
}

provider "docker" {
  host = "ssh://root@${var.remote_ip}"
}

# 使用模块定义 MySQL
module "mysql" {
  source = "./modules/app"

  app_name             = "mysql"
  image                = "library/mysql:8.0.23"
  remote_host          = var.remote_ip
  ssh_user             = "root"
  ssh_private_key_path = "~/.ssh/id_rsa"

  env = [
    "MYSQL_ROOT_PASSWORD=",
    "MYSQL_MAX_CONNECTIONS=2000"
  ]

  ports = [{ internal = 3306, external = 3306 }]

  # 优雅：本地路径 => 远程及容器内路径
  config_files = {
    "${path.module}/my.cnf"    = "/home/mysql-R2.3.3.0/conf.d/my.cnf"
    "${path.module}/mysql.env" = "/home/mysql-R2.3.3.0/env/mysql.env"
  }

  data_volumes = {
    "/home/mysql-R2.3.3.0-ansible/data" = "/var/lib/mysql"
  }

  healthcheck = {
    test         = ["CMD", "mysqladmin", "ping", "-h", "localhost"]
    interval     = "5s"
    timeout      = "10s"
    retries      = 30
    start_period = "60s"
  }
}

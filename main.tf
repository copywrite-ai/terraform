terraform {
  required_version = ">= 1.4.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 3.0"
    }
  }
}

variable "docker_host" {
  type    = string
  default = "unix:///var/run/docker.sock"
}

variable "ssh_host" {
  type    = string
  default = "127.0.0.1"
}

variable "ssh_user" {
  type    = string
  default = "root"
}

variable "ssh_key_path" {
  type    = string
  default = "/root/.ssh/id_ed25519"
}

variable "remote_data_dir" {
  type    = string
  default = "/root/terraform-codex"
}

provider "docker" {
  host = var.docker_host
}

variable "host_project_dir" {
  type    = string
  default = ""
}

locals {
  project_root = var.host_project_dir != "" ? var.host_project_dir : path.cwd
}

# 1. 准备远程目录并上传备份数据
resource "null_resource" "backup_distribution" {
  connection {
    type        = "ssh"
    host        = var.ssh_host
    user        = var.ssh_user
    private_key = file(var.ssh_key_path)
    agent       = false
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p ${var.remote_data_dir}/backups"]
  }

  provisioner "file" {
    source      = "backups/"
    destination = "${var.remote_data_dir}/backups"
  }
}

module "mysql" {
  source = "./modules/mysql"

  project_root  = local.project_root
  root_password = "p@ssword"
  database_name = "hello-world"

  ssh_host     = var.ssh_host
  ssh_user     = var.ssh_user
  ssh_key_path = var.ssh_key_path
}

module "mydumper" {
  source = "./modules/mydumper"

  project_root  = local.project_root
  root_password = "p@ssword"
  database_name = "hello-world"
  backups_path  = "${var.remote_data_dir}/backups"
  mysql_container_name = module.mysql.container_name

  ssh_host     = var.ssh_host
  ssh_user     = var.ssh_user
  ssh_key_path = var.ssh_key_path

  depends_on = [module.mysql, null_resource.backup_distribution]
}

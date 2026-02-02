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

variable "restore_enabled" {
  type    = bool
  default = true
}

variable "backup_source" {
  type    = string
  default = "local"
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
  local_backups_dir  = "./backups"
  remote_backups_dir = "${var.remote_data_dir}/backups"
  backup_source = var.backup_source
  restore_enabled = var.restore_enabled
  mysql_container_name = module.mysql.container_name

  ssh_host     = var.ssh_host
  ssh_user     = var.ssh_user
  ssh_key_path = var.ssh_key_path

  depends_on = [module.mysql]
}

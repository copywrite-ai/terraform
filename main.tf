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
  default = ""
}

# SSH connection settings for remote Docker host access (used by provisioners).
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

# Base directory on the remote host for staging backups and related files.
variable "remote_data_dir" {
  type    = string
  default = "/tmp/terraform-codex"
}

# Toggle the restore workflow on/off for demo convenience.
variable "restore_enabled" {
  type    = bool
  default = true
}

# Where backups come from: "local" copies ./backups to remote, "remote" assumes pre-staged.
variable "backup_source" {
  type    = string
  default = "local"
}

provider "docker" {
  host = var.docker_host != "" ? var.docker_host : "ssh://${var.ssh_user}@${var.ssh_host}"
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

# Restore task: waits for MySQL health, stages backups (if local), then runs myloader.
module "mydumper" {
  source = "./modules/mydumper"

  project_root  = local.project_root
  root_password = "p@ssword"
  database_name = "hello-world"
  local_backups_dir  = "${path.root}/backups"
  remote_backups_dir = "${var.remote_data_dir}/backups"
  backup_source = var.backup_source
  restore_enabled = var.restore_enabled
  mysql_container_name = module.mysql.container_name
  mysql_container_id   = module.mysql.container_id

  ssh_host     = var.ssh_host
  ssh_user     = var.ssh_user
  ssh_key_path = var.ssh_key_path

  depends_on = [module.mysql]
}

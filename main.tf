terraform {
  required_version = ">= 1.4.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 3.0"
    }
  }
}

provider "docker" {}

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
}

module "mydumper" {
  source = "./modules/mydumper"

  project_root  = local.project_root
  root_password = "p@ssword"
  database_name = "hello-world"
  backups_path  = "${local.project_root}/backups"

  depends_on = [module.mysql]
}

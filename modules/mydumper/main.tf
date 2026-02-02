terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 3.0"
    }
  }
}

variable "project_root" {
  type    = string
  default = ""
}

variable "root_password" {
  type = string
}

variable "database_name" {
  type = string
}

variable "backups_path" {
  type = string
}

variable "mysql_container_name" {
  type = string
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

resource "docker_image" "mydumper" {
  name = "docker.1ms.run/mydumper/mydumper:latest"
}

resource "docker_container" "mydumper" {
  name  = "hello-world-myloader"
  image = docker_image.mydumper.image_id

  network_mode = "host"
  privileged   = true
  restart      = "no"
  must_run     = false
  rm           = false

  command = [
    "sh",
    "-c",
    "myloader -h 127.0.0.1 -u root --password '${var.root_password}' -B ${var.database_name} -d /backups",
  ]

  volumes {
    host_path      = var.backups_path
    container_path = "/backups"
    read_only      = false
  }

  depends_on = [null_resource.wait_for_mysql_health]
}

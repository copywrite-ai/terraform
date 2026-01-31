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

resource "docker_image" "mydumper" {
  name = "docker.1ms.run/mydumper/mydumper:latest"
}

resource "docker_container" "mydumper" {
  name  = "hello-world-mydumper"
  image = docker_image.mydumper.image_id

  network_mode = "host"
  restart      = "no"
  must_run     = false
  rm           = true

  command = [
    "sh",
    "-c",
    "until python3 -c \"import socket; socket.create_connection(('127.0.0.1', 3306), timeout=1)\" 2>/dev/null; do sleep 1; done; mydumper -h 127.0.0.1 -u root --password '${var.root_password}' -B ${var.database_name} -o /backups",
  ]

  volumes {
    host_path      = var.backups_path
    container_path = "/backups"
    read_only      = false
  }
}

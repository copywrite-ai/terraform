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

resource "docker_image" "mysql" {
  name = "docker.1ms.run/library/mysql:8.0.32"
}

resource "docker_container" "mysql" {
  name  = "hello-world-mysql"
  image = docker_image.mysql.image_id

  restart = "always"
  network_mode = "host"

  env = [
    "MYSQL_ROOT_PASSWORD=${var.root_password}",
    "MYSQL_DATABASE=${var.database_name}",
  ]

  volumes {
    host_path      = var.project_root != "" ? "${var.project_root}/modules/mysql/init.sql" : abspath("${path.module}/init.sql")
    container_path = "/docker-entrypoint-initdb.d/init.sql"
    read_only      = true
  }
}

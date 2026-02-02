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

  healthcheck {
    test         = ["CMD-SHELL", "mysqladmin ping -h 127.0.0.1 -uroot -p${var.root_password} --silent"]
    interval     = "5s"
    timeout      = "2s"
    retries      = 20
    start_period = "5s"
  }
}

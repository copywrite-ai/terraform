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

variable "remote_backups_dir" {
  type = string
}

variable "mysql_container_name" {
  type = string
}

variable "mysql_container_id" {
  type = string
}

variable "staging_trigger" {
  type    = string
  default = ""
}

variable "restore_enabled" {
  type    = bool
  default = true
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

# Ensure remote backups directory exists regardless of source.
# Run myloader as a one-off restore task.
resource "docker_container" "mydumper" {
  count = var.restore_enabled ? 1 : 0

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
    host_path      = var.remote_backups_dir
    container_path = "/backups"
    read_only      = false
  }

  labels {
    label = "restore.staging_trigger"
    value = var.staging_trigger
  }

  depends_on = [null_resource.wait_for_mysql_health]
}

# Print restore logs to make demo results visible in apply output.
resource "null_resource" "show_restore_logs" {
  count = var.restore_enabled ? 1 : 0

  connection {
    type        = "ssh"
    host        = var.ssh_host
    user        = var.ssh_user
    private_key = file(var.ssh_key_path)
    agent       = false
  }

  provisioner "remote-exec" {
    inline = [
      "echo '--- myloader logs (hello-world-myloader) ---'",
      "docker logs hello-world-myloader || true",
    ]
  }

  depends_on = [docker_container.mydumper]
}

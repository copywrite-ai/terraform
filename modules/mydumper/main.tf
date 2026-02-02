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

variable "local_backups_dir" {
  type = string
}

variable "remote_backups_dir" {
  type = string
}

variable "backup_source" {
  type    = string
  default = "local"
  validation {
    condition     = contains(["local", "remote"], var.backup_source)
    error_message = "backup_source must be \"local\" or \"remote\"."
  }
}

variable "mysql_container_name" {
  type = string
}

variable "mysql_container_id" {
  type = string
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

resource "null_resource" "ensure_backups_dir" {
  count = var.restore_enabled ? 1 : 0

  connection {
    type        = "ssh"
    host        = var.ssh_host
    user        = var.ssh_user
    private_key = file(var.ssh_key_path)
    agent       = false
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p ${var.remote_backups_dir}"]
  }
}

resource "null_resource" "stage_backups" {
  count = var.restore_enabled && var.backup_source == "local" ? 1 : 0
  triggers = {
    backup_fingerprint = sha256(join("", [
      for f in fileset(var.local_backups_dir, "**") :
      filesha256("${var.local_backups_dir}/${f}")
    ]))
  }

  connection {
    type        = "ssh"
    host        = var.ssh_host
    user        = var.ssh_user
    private_key = file(var.ssh_key_path)
    agent       = false
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p ${var.remote_backups_dir}"]
  }

  provisioner "file" {
    source      = "${var.local_backups_dir}/"
    destination = var.remote_backups_dir
  }
}

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

  depends_on = [null_resource.wait_for_mysql_health, null_resource.ensure_backups_dir, null_resource.stage_backups]
}

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

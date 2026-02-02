variable "local_dir" {
  type = string
}

variable "remote_dir" {
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

variable "enabled" {
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

# Ensure the remote directory exists.
resource "null_resource" "ensure_remote_dir" {
  count = var.enabled ? 1 : 0

  connection {
    type        = "ssh"
    host        = var.ssh_host
    user        = var.ssh_user
    private_key = file(var.ssh_key_path)
    agent       = false
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p ${var.remote_dir}"]
  }
}

# Copy local directory to the remote host when source == local.
resource "null_resource" "stage_copy" {
  count = var.enabled && var.backup_source == "local" ? 1 : 0

  triggers = {
    dir_fingerprint = sha256(join("", [
      for f in fileset(var.local_dir, "**") :
      filesha256("${var.local_dir}/${f}")
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
    inline = ["mkdir -p ${var.remote_dir}"]
  }

  provisioner "file" {
    source      = "${var.local_dir}/"
    destination = var.remote_dir
  }
}

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 3.0.1"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
  }
}

# 1. 自动创建远程目录 (执行一次)
resource "null_resource" "directories" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = var.remote_host
  }

  provisioner "remote-exec" {
    inline = flatten([
      for local, remote in var.config_files : [
        "mkdir -p $(dirname ${remote})"
      ]
    ])
  }
}

# 2. 自动分发文件 (每个文件一个资源实例)
resource "null_resource" "file_distribution" {
  for_each = var.config_files

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = var.remote_host
  }

  provisioner "file" {
    source      = each.key
    destination = each.value
  }

  depends_on = [null_resource.directories]
}

# 3. 容器定义
resource "docker_container" "this" {
  name  = var.app_name
  image = var.image

  # 必须等所有文件都分发完
  depends_on = [null_resource.file_distribution]

  env = var.env
# ... (rest of the file remains the same, but I'll replace the block to be sure)
  dynamic "ports" {
    for_each = var.ports
    content {
      internal = ports.value.internal
      external = ports.value.external
    }
  }

  dynamic "volumes" {
    for_each = var.config_files
    content {
      host_path      = volumes.value
      container_path = volumes.value
    }
  }

  dynamic "volumes" {
    for_each = var.data_volumes
    content {
      host_path      = volumes.key
      container_path = volumes.value
    }
  }

  dynamic "healthcheck" {
    for_each = var.healthcheck != null ? [var.healthcheck] : []
    content {
      test         = healthcheck.value.test
      interval     = healthcheck.value.interval
      timeout      = healthcheck.value.timeout
      retries      = healthcheck.value.retries
      start_period = healthcheck.value.start_period
    }
  }
}

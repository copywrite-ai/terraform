# 1. 自动处理目录与文件分发
resource "null_resource" "file_distribution" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = var.remote_host
  }

  # 自动创建所有配置文件所在的目录
  provisioner "remote-exec" {
    inline = flatten([
      for local, remote in var.config_files : [
        "mkdir -p $(dirname ${remote})"
      ]
    ])
  }

  # 自动分发文件
  dynamic "provisioner" {
    for_each = var.config_files
    content {
      source      = provisioner.key # 本地文件路径
      destination = provisioner.value # 远程目标路径
    }
  }
}

# 2. 容器定义
resource "docker_container" "this" {
  name  = var.app_name
  image = var.image

  depends_on = [null_resource.file_distribution]

  env = var.env

  dynamic "ports" {
    for_each = var.ports
    content {
      internal = ports.value.internal
      external = ports.value.external
    }
  }

  # 自动挂载配置文件
  dynamic "volumes" {
    for_each = var.config_files
    content {
      host_path      = volumes.value
      container_path = volumes.value
    }
  }

  # 挂载数据卷
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

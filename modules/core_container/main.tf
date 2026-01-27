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
  count = (var.ssh_user == "local" || length(var.config_files) == 0) ? 0 : 1
  
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
  for_each = var.ssh_user == "local" ? {} : var.config_files

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

# 3. 压缩包分发与解压
resource "null_resource" "archives" {
  count = (var.ssh_user == "local" || length(var.archives) == 0) ? 0 : length(var.archives)

  triggers = {
    source_hash = filesha256(var.archives[count.index].source)
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = var.remote_host
  }

  provisioner "file" {
    source      = var.archives[count.index].source
    destination = "${var.archives[count.index].destination}.${count.index}.tmp"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${var.archives[count.index].destination}",
      var.archives[count.index].type == "tar.gz" ? "tar -xzf ${var.archives[count.index].destination}.${count.index}.tmp -C ${var.archives[count.index].destination}" : "unzip -o ${var.archives[count.index].destination}.${count.index}.tmp -d ${var.archives[count.index].destination}",
      "rm -f ${var.archives[count.index].destination}.${count.index}.tmp"
    ]
  }

  depends_on = [null_resource.directories]
}

# 4. 镜像拉取 (增强型：支持离线已存在镜像，避免拉取报错)
resource "null_resource" "image_pull" {
  count = var.ssh_user == "local" ? 0 : 1
  triggers = {
    image = var.image
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.remote_host
    private_key = file(var.ssh_private_key_path)
  }

  # 先检查本地是否存在，不存在再拉取，即便拉取失败也仅输出警告而不中断流程
  provisioner "remote-exec" {
    inline = [
      "docker inspect ${var.image} >/dev/null 2>&1 || docker pull ${var.image} || echo 'Warning: Pull failed, relying on local image'"
    ]
  }
}

resource "docker_image" "this" {
  name = var.image
  # 除非镜像名变了，否则不盲目触发 Provider 的 Pull 逻辑 (提升性能/容错)
  pull_triggers = var.ssh_user == "local" ? [] : [null_resource.image_pull[0].id]
  keep_locally  = true
}

# 5. 容器启动前的远程命令 (Hook)
resource "null_resource" "pre_start_hooks" {
  count = (var.ssh_user == "local" || var.pre_start_command == "") ? 0 : 1

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = var.remote_host
  }

  provisioner "remote-exec" {
    inline = [var.pre_start_command]
  }

  depends_on = [
    null_resource.file_distribution,
    null_resource.archives,
    docker_image.this
  ]
}

# 6. 容器定义
resource "docker_container" "this" {
  name  = var.app_name
  image = docker_image.this.image_id

  # 必须等所有文件、压缩包以及 Hook 都执行完 (仅在 SSH 模式下)
  depends_on = [
    null_resource.file_distribution,
    null_resource.directories,
    null_resource.archives,
    null_resource.pre_start_hooks
  ]

  must_run     = var.must_run
  wait         = var.wait
  wait_timeout = var.wait_timeout

  privileged    = var.privileged
  security_opts = var.security_opts
  network_mode  = var.network_mode

  dynamic "networks_advanced" {
    for_each = var.networks
    content {
      name = networks_advanced.value
    }
  }

  env     = var.env
  command = var.command
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
      # 如果是本地模式，直接挂载源码文件作为 Host Path
      # 如果是 SSH 模式，挂载已通过 Provisioner 到达远程的 Destination Path
      host_path      = var.ssh_user == "local" ? volumes.key : volumes.value
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

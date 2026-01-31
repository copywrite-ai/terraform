################################################################################
# Docker App Module - 统一的容器部署模块
################################################################################
#
# 支持：
# - 常驻服务（默认）
# - 一次性任务（is_oneshot = true）
# - 配置文件分发
# - 健康检查
# - 串行依赖（通过 depends_on_ready 输入）
#
################################################################################

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}

locals {
  # 对于一次性任务，强制使用带有时间戳的名称，确保每次 apply 都会触发重建
  container_name = var.is_oneshot ? "${var.app_name}-${formatdate("YYYYMMDDhhmmss", timestamp())}" : var.app_name
}

# ============================================================================
# 0. 依赖锚点（强制串行部署）
# ============================================================================
# 通过 triggers 引用上游 ready 信号，Terraform 会自动建立隐式依赖
# 关键：triggers 中的值必须来自上游资源的输出，这样 Terraform 才会等待上游完成
resource "null_resource" "dependency_anchor" {
  triggers = {
    # 通过引用上游模块的 ready 输出，建立隐式依赖
    # Terraform 会等待 depends_on_ready 对应的资源完成后才创建本资源
    dependency_id = var.depends_on_ready
  }

  # 额外的显式等待：通过 provisioner 确保上游已真正就绪
  # 这是一个防护措施，确保在某些边缘情况下也能正确等待
  provisioner "local-exec" {
    command = "echo 'Dependency ready: ${var.depends_on_ready}'"
  }
}

# ============================================================================
# 1. 单文件分发
# ============================================================================
resource "null_resource" "file_distribution" {
  depends_on = [null_resource.dependency_anchor]
  for_each   = var.config_files

  triggers = {
    content_hash = filesha256(each.key)
  }

  connection {
    type        = "ssh"
    user        = var.host.user
    private_key = file(var.host.key_path)
    host        = var.host.ip
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p $(dirname ${each.value})"]
  }

  provisioner "file" {
    source      = each.key
    destination = each.value
  }
}

# ============================================================================
# 2. 压缩包分发（单个）
# ============================================================================
resource "null_resource" "archive_distribution" {
  depends_on = [null_resource.dependency_anchor]
  count      = var.archive != null ? 1 : 0

  triggers = {
    source_hash = filesha256(var.archive.source)
  }

  connection {
    type        = "ssh"
    user        = var.host.user
    private_key = file(var.host.key_path)
    host        = var.host.ip
  }

  provisioner "file" {
    source      = var.archive.source
    destination = "/tmp/${var.app_name}_archive.${var.archive.type == "tar.gz" ? "tar.gz" : "zip"}"
  }

  provisioner "remote-exec" {
    inline = [
      "rm -rf ${var.archive.destination}",
      "mkdir -p ${var.archive.destination}",
      var.archive.type == "tar.gz"
        ? "tar -xzf /tmp/${var.app_name}_archive.tar.gz -C ${var.archive.destination}"
        : "unzip -o /tmp/${var.app_name}_archive.zip -d ${var.archive.destination}",
      "rm -f /tmp/${var.app_name}_archive.*"
    ]
  }
}

# ============================================================================
# 3. 镜像准备
# ============================================================================
resource "docker_image" "this" {
  depends_on   = [null_resource.dependency_anchor]
  name         = var.image
  keep_locally = true
}

# ============================================================================
# 4. 一次性任务：强制重建触发器
# ============================================================================
resource "null_resource" "force_recreate" {
  count = var.is_oneshot ? 1 : 0

  triggers = {
    always_run = timestamp()
  }
}

# ============================================================================
# 5. 容器定义
# ============================================================================
resource "docker_container" "this" {
  name  = local.container_name
  image = docker_image.this.image_id

  depends_on = [
    null_resource.file_distribution,
    null_resource.archive_distribution,
  ]

  # 运行配置
  must_run     = var.is_oneshot ? false : true
  wait         = false  # 统一不使用 docker wait，通过外部 null_resource 等待健康
  wait_timeout = var.wait_timeout
  restart      = var.is_oneshot ? "no" : var.restart

  network_mode = var.network_mode
  privileged   = var.privileged

  env     = var.env
  command = var.command

  # 端口映射
  dynamic "ports" {
    for_each = var.ports
    content {
      internal = ports.value.internal
      external = ports.value.external
    }
  }

  # 数据卷
  dynamic "volumes" {
    for_each = var.volumes
    content {
      host_path      = can(regex("^/", volumes.key)) ? volumes.key : null
      volume_name    = can(regex("^/", volumes.key)) ? null : volumes.key
      container_path = volumes.value
    }
  }

  # 配置文件挂载（远程路径）
  dynamic "volumes" {
    for_each = var.config_files
    content {
      host_path      = volumes.value
      container_path = volumes.value
    }
  }

  # 健康检查
  dynamic "healthcheck" {
    for_each = var.healthcheck != null ? [var.healthcheck] : []
    content {
      test         = healthcheck.value.test
      interval     = healthcheck.value.interval
      timeout      = healthcheck.value.timeout
      retries      = healthcheck.value.retries
      start_period = lookup(healthcheck.value, "start_period", "0s")
    }
  }
}

# ============================================================================
# 6. 等待健康检查通过（常驻服务）
# ============================================================================
resource "null_resource" "wait_healthy" {
  count = var.healthcheck != null && !var.is_oneshot ? 1 : 0

  depends_on = [docker_container.this]

  connection {
    type        = "ssh"
    user        = var.host.user
    private_key = file(var.host.key_path)
    host        = var.host.ip
  }

  provisioner "remote-exec" {
    inline = [
      "echo '=========================================='",
      "echo '[DEBUG] Starting health check wait for: ${var.app_name}'",
      "echo '[DEBUG] Timestamp: '$(date '+%Y-%m-%d %H:%M:%S')",
      "echo '[DEBUG] Max retries: ${var.health_check_retries}, Interval: ${var.health_check_interval}s'",
      "echo '=========================================='",
      "# 首先检查容器是否存在且在运行",
      "if ! docker ps --format '{{.Names}}' | grep -q '^${var.app_name}$'; then",
      "  echo '[ERROR] Container ${var.app_name} is not running!'",
      "  docker ps -a --filter name=${var.app_name}",
      "  exit 1",
      "fi",
      "echo '[DEBUG] Container ${var.app_name} is running, starting health check loop...'",
      "for i in $(seq 1 ${var.health_check_retries}); do",
      "  status=$(docker inspect --format='{{.State.Health.Status}}' ${var.app_name} 2>/dev/null || echo 'no-healthcheck')",
      "  running=$(docker inspect --format='{{.State.Running}}' ${var.app_name} 2>/dev/null || echo 'false')",
      "  echo \"[DEBUG] Attempt $i/60: health=$status, running=$running, time=$(date '+%H:%M:%S')\"",
      "  if [ \"$status\" = \"healthy\" ]; then",
      "    echo '=========================================='",
      "    echo '[SUCCESS] ${var.app_name} is healthy!'",
      "    echo '[DEBUG] Timestamp: '$(date '+%Y-%m-%d %H:%M:%S')",
      "    echo '=========================================='",
      "    exit 0",
      "  fi",
      "  if [ \"$running\" != \"true\" ]; then",
      "    echo '[ERROR] Container stopped unexpectedly!'",
      "    docker logs --tail 50 ${var.app_name}",
      "    exit 1",
      "  fi",
      "  sleep ${var.health_check_interval}",
      "done",
      "echo '=========================================='",
      "echo '[FAILED] Health check timeout for ${var.app_name}'",
      "echo '[DEBUG] Final container logs:'",
      "docker logs --tail 30 ${var.app_name}",
      "echo '=========================================='",
      "exit 1"
    ]
  }
}

################################################################################
# Docker App Module - 输出定义
################################################################################

output "container_id" {
  description = "容器 ID"
  value       = docker_container.this.id
}

output "container_name" {
  description = "容器名称"
  value       = docker_container.this.name
}

# 用于下游模块建立依赖的标志
# 下游模块通过 depends_on_ready = module.xxx.ready 来等待本模块完成
output "ready" {
  description = "模块就绪标志（用于串行依赖）"
  value       = var.healthcheck != null && !var.is_oneshot ? (
    null_resource.wait_healthy[0].id
  ) : docker_container.this.id
}

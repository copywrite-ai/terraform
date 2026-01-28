# 容器 ID，用于建立模块间依赖关系
output "container_id" {
  value       = docker_container.this.id
  description = "The ID of the created container. Use this to create implicit dependencies between modules."
}

# 容器名称
output "container_name" {
  value       = docker_container.this.name
  description = "The name of the created container."
}

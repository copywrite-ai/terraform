output "db_private_ip" {
  # 技巧：通过引用 container_id 强制 Terraform 等待容器创建并通过健康检查
  value       = module.mysql_container.container_id != "" ? "172.24.216.194" : ""
  description = "数据库服务的私网 IP（等待容器健康后才输出）"
}

output "container_id" {
  value       = module.mysql_container.container_id
  description = "MySQL 容器 ID，用于建立模块间依赖"
}

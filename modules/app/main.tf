################################################################################
# mydumper 数据恢复任务模块
################################################################################
# 
# 这是一个一次性任务模块，用于将 SQL 备份恢复到目标数据库。
# 通过设置 must_run = false，容器执行完成后正常退出不会报错。
#
################################################################################

module "migration_container" {
  source = "../core_container"

  app_name             = "mydumper-restore"
  image                = "docker.1ms.run/mydumper/mydumper:latest"
  remote_host          = var.remote_host
  ssh_user             = var.ssh_user
  ssh_private_key_path = var.ssh_private_key_path

  # 共享备份目录
  data_volumes = {
    "${var.host_data_path}" = "/backups"
  }

  # 自动分发与解压 SQL 备份包
  archives = [{
    source      = var.sql_backup_path
    destination = "${var.host_data_path}/host_data"
    type        = "zip"
  }]

  # 执行数据恢复命令
  command = [
    "sh", "-c",
    "myloader --host=${var.database_ip} --user=root --password='' --directory=/backups/host_data --overwrite-tables --verbose=3"
  ]

  # 【关键配置】一次性任务设置
  wait         = false   # 不等待容器持续运行
  must_run     = false   # 允许容器正常退出
  privileged   = true    # 需要特权模式运行 myloader
  network_mode = "host"  # 使用宿主机网络
}

# 输出容器 ID，方便下游模块建立依赖
output "container_id" {
  value       = module.migration_container.container_id
  description = "mydumper 恢复任务容器 ID"
}

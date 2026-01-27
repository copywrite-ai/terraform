module "migration_container" {
  source = "../core_container"

  app_name             = "migration"
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

  # 使用传入的 database_ip
  command      = ["sh", "-c", "myloader --host=${var.database_ip} --user=root --password='' --directory=/backups/host_data --overwrite-tables --verbose=3"]
  wait         = false
  must_run     = false
  privileged   = true
  network_mode = "host"
}

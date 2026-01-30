################################################################################
# 主编排文件 - 串行部署示例
################################################################################
#
# 依赖链：MySQL → MySQL Init → App
# 
# module.mysql.ready → module.mysql_init.ready → module.app.ready
#
################################################################################

# ============================================================================
# 数据准备
# ============================================================================

data "archive_file" "mysql_backup" {
  type        = "zip"
  # 使用当前项目目录下的备份数据（已从参考项目复制）
  source_dir  = "${path.module}/data/host_data"
  output_path = "${path.module}/mysql_backup.zip"
}

# ============================================================================
# MySQL 数据库（常驻服务）
# ============================================================================
module "mysql" {
  source = "./modules/docker_app"
  providers = {
    docker = docker.host_a
  }

  app_name = "mysql"
  image    = "docker.1ms.run/library/mysql:8.0.32"
  host     = var.hosts["host_a"]

  network_mode = "host"

  env = [
    "MYSQL_ALLOW_EMPTY_PASSWORD=yes",
    "MYSQL_DATABASE=mydb"
  ]

  # 使用主机路径绑定挂载（比 Docker 命名卷更可靠）
  volumes = {
    "/root/mysql_data" = "/var/lib/mysql"
  }

  healthcheck = {
    test         = ["CMD", "mysqladmin", "ping", "-h", "localhost"]
    interval     = "5s"
    timeout      = "10s"
    retries      = 30
    start_period = "60s"  # MySQL 8.0 首次初始化需要较长时间
  }

  # 首次部署时禁用自动重启，避免初始化失败时进入污染循环
  # 健康检查通过后可以手动更新为 "unless-stopped"
  restart = "no"

  # 增加健康检查等待时间（总计 120 秒）
  health_check_retries  = 60
  health_check_interval = 2
}

# ============================================================================
# MySQL 初始化（一次性任务）
# ============================================================================
module "mysql_init" {
  source = "./modules/docker_app"
  providers = {
    docker = docker.host_a
  }

  app_name   = "mysql-init"
  image      = "docker.1ms.run/mydumper/mydumper:latest"
  host       = var.hosts["host_a"]
  is_oneshot = true

  network_mode = "host"
  privileged   = true

  # 严格串行依赖：等待 MySQL 模块完全就绪
  depends_on_ready = module.mysql.ready

  # 分发备份数据
  archive = {
    source      = data.archive_file.mysql_backup.output_path
    destination = "/root/mysql_backups"
    type        = "zip"
  }

  # 挂载备份目录
  volumes = {
    "/root/mysql_backups" = "/backups"
  }

  command = [
    "sh", "-c",
    "myloader --host=127.0.0.1 --user=root --password='' --directory=/backups --overwrite-tables --verbose=3"
  ]
}

# ============================================================================
# 业务应用（常驻服务）
# ============================================================================
# module "app" {
#   source = "./modules/docker_app"
#   providers = {
#     docker = docker.host_a  # 或 docker.host_b 部署到其他主机
#   }
#
#   app_name = "my-app"
#   image    = "my-app:latest"
#   host     = var.hosts["host_a"]
#
#   # 等待初始化完成
#   depends_on_ready = module.mysql_init.ready
#
#   env = [
#     "DATABASE_URL=mysql://root:YOUR_PASSWORD@127.0.0.1:3306/mydb"
#   ]
# }

# ============================================================================
# 输出
# ============================================================================
output "mysql_ready" {
  value = module.mysql.ready
}

output "mysql_init_ready" {
  value = module.mysql_init.ready
}

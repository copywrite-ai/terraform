# Terraform Multi-Host Docker Deployment

简洁的多主机 Docker 容器部署架构。

## 目录结构

```
.
├── main.tf              # 编排入口（定义应用及依赖）
├── providers.tf         # 多主机 Docker Provider
├── variables.tf         # 变量定义
├── terraform.tfvars     # 变量值
├── run.sh               # Docker 运行 Terraform
├── prepare_plugins.sh   # 离线插件准备
└── modules/
    └── docker_app/      # 统一的应用模块
```

## 快速开始

```bash
# 1. 准备离线插件（可选，首次运行）
./prepare_plugins.sh

# 2. 初始化
./run.sh init

# 3. 预览变更
./run.sh plan

# 4. 部署
./run.sh apply
```

## 核心特性

### 多主机支持

在 `providers.tf` 中定义多个 provider alias：

```hcl
provider "docker" {
  alias = "host_a"
  host  = "ssh://root@1.2.3.4"
}

provider "docker" {
  alias = "host_b"
  host  = "ssh://root@5.6.7.8"
}
```

### 串行依赖

通过 `depends_on_ready` 建立模块间依赖：

```hcl
module "mysql" { ... }

module "mysql_init" {
  depends_on_ready = module.mysql.ready  # 等待 MySQL 健康后执行
}

module "app" {
  depends_on_ready = module.mysql_init.ready  # 等待初始化完成
}
```

### 一次性任务

设置 `is_oneshot = true`，每次 `apply` 都会重新执行：

```hcl
module "migration" {
  is_oneshot = true
  command    = ["./migrate.sh"]
}
```

### 配置文件分发

支持单文件和压缩包分发：

```hcl
module "app" {
  config_files = {
    "./config/app.conf" = "/etc/app/app.conf"
  }
  
  archive = {
    source      = "./data.tar.gz"
    destination = "/opt/data"
    type        = "tar.gz"
  }
}
```

## 如何添加新应用

### 1. 添加常驻应用 (Resident Service)
适用于 Web 服务、数据库等需要持续运行并提供健康状态的应用。

1. 在 `main.tf` 中定义模块：
   ```hcl
   module "my_service" {
     source   = "./modules/docker_app"
     app_name = "my-service"
     image    = "my-repo/my-image:latest"
     host     = var.hosts["host_a"]
     
     # 设置健康检查，以便其他应用依赖它
     healthcheck = {
       test     = ["CMD", "curl", "-f", "http://localhost:8080/health"]
       interval = "10s"
       retries  = 3
     }
   }
   ```
2. (可选) 通过 `module.my_service.ready` 暴露给下游。

### 2. 添加一次性应用 (One-shot Task)
适用于数据库迁移、初始化脚本、数据备份等执行完即退出的任务。

1. 在 `main.tf` 中定义模块并设置 `is_oneshot = true`：
   ```hcl
   module "db_init" {
     source     = "./modules/docker_app"
     app_name   = "db-init"
     image      = "busybox"
     is_oneshot = true
     
     # 依赖常驻服务
     depends_on_ready = module.mysql.ready
     
     command = ["sh", "-c", "echo 'Initializing...' && sleep 5"]
   }
   ```
2. 设置 `depends_on_ready` 确保它在正确的时机执行。

## 添加新主机

1. 在 `terraform.tfvars` 添加主机配置
2. 在 `providers.tf` 添加对应的 provider alias
3. 在 module 中指定 `providers = { docker = docker.new_host }`

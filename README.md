# Terraform 多主机 Docker 管理架构

本项目采用 Terraform 实现多主机 Docker 容器自动化部署与管理，支持：
- 通过 SSH 远程管理多台服务器上的 Docker 容器
- 每个服务对应一个独立模块，支持**常驻服务**和**一次性任务**
- 模块间通过健康检查驱动的依赖关系，确保上游服务就绪后才启动下游

---

## 架构概览

```plaintext
terraform-hospital/
├── main.tf                     # 主编排文件：定义 Provider 和模块调用
├── variables.tf                # 全局变量：主机配置、服务参数
│
├── modules/
│   ├── core_container/         # 核心模块：通用容器管理
│   │   ├── main.tf             # 容器资源定义
│   │   ├── variables.tf        # 输入变量
│   │   └── outputs.tf          # 输出（container_id 用于依赖）
│   │
│   ├── db/                     # MySQL 数据库服务模块
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── app/                    # 一次性任务模块（如 mydumper 恢复）
│       ├── main.tf
│       └── variables.tf
│
└── data/                       # 静态资源目录
    └── host_data/              # SQL 备份文件
```

---

## 核心特性

### 1. 多主机支持

在 `variables.tf` 中定义主机列表：

```hcl
variable "hosts" {
  default = {
    host_a = {
      ip                   = "106.14.26.23"
      ssh_user             = "root"
      ssh_private_key_path = "~/.ssh/id_ed25519"
      data_path            = "/root/terraform/data"
    }
    host_b = { ip = "", ... }  # 待填写
    host_c = { ip = "", ... }  # 待填写
  }
}

variable "active_host" {
  default = "host_a"  # 当前部署目标
}
```

部署时通过 `-var` 切换目标主机：

```bash
terraform apply -var="active_host=host_b"
```

### 2. 常驻服务 vs 一次性任务

| 类型 | `must_run` | `wait` | 说明 |
|------|-----------|--------|------|
| 常驻服务 | `true` (默认) | `true` | 容器必须持续运行，退出则报错 |
| 一次性任务 | `false` | `false` | 容器执行完成后正常退出 |

### 3. 健康检查与依赖管理

**MySQL 模块** 配置了健康检查：
```hcl
healthcheck = {
  test         = ["CMD", "mysqladmin", "ping", "-h", "localhost"]
  interval     = "5s"
  timeout      = "10s"
  retries      = 30
  start_period = "60s"
}
```

**依赖实现原理**：
```hcl
# main.tf 中
module "mydumper_restore" {
  source      = "./modules/app"
  database_ip = module.mysql.db_private_ip  # 引用上游输出
}
```

由于 `db_private_ip` 的值依赖于 `container_id`，而 `container_id` 只有在容器创建并通过健康检查后才会输出，因此 Terraform 会**自动等待 MySQL 就绪后**才启动 mydumper 任务。

---

## 快速开始

### 前置要求
- 本地安装 Docker（用于运行 Terraform）
- SSH 密钥配置完成（默认 `~/.ssh/id_ed25519`）
- 远程服务器已安装 Docker

### 初始化
```bash
docker run --rm \
  -v $(pwd):/workspace \
  -v ~/.ssh:/root/.ssh \
  -w /workspace \
  hashicorp/terraform:latest init
```

### 部署到 host_a
```bash
docker run --rm \
  -v $(pwd):/workspace \
  -v ~/.ssh:/root/.ssh \
  -w /workspace \
  hashicorp/terraform:latest apply -auto-approve
```

### 部署到其他主机
```bash
terraform apply -var="active_host=host_b"
```

---

## 模块说明

### `modules/core_container`
通用容器管理模块，支持：
- 文件分发（`config_files`）
- 压缩包分发与解压（`archives`）
- 镜像拉取（支持离线模式）
- 健康检查
- 常驻/任务模式切换（`must_run`）

### `modules/db`
MySQL 数据库服务模块：
- 自动创建数据库（`MYSQL_DATABASE`）
- 配置健康检查
- 输出 `db_private_ip` 和 `container_id`

### `modules/app`
mydumper 数据恢复任务模块：
- 一次性任务（`must_run = false`）
- 依赖 MySQL 健康后才执行
- 自动分发并解压 SQL 备份

---

## 扩展指南

### 添加新主机
编辑 `variables.tf` 中的 `hosts` 变量：
```hcl
host_d = {
  ip                   = "192.168.1.100"
  ssh_user             = "root"
  ssh_private_key_path = "~/.ssh/id_ed25519"
  data_path            = "/data/terraform"
}
```

### 添加新服务
1. 在 `modules/` 下创建新目录
2. 调用 `core_container` 模块
3. 在 `main.tf` 中引用新模块并配置依赖

### 添加新任务
复制 `modules/app` 并修改 `command` 即可。

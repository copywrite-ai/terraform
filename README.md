# Terraform 模块化组合部署方案 (DB + App)

本项目采用 Terraform “父模块（Root Module）调用子模块（Sub-modules）” 的地道模式，实现了数据库（MySQL）与应用（Migration）的自动化部署与依赖管理。

## 核心架构：模块化组合 (Module Composition)

项目通过将资源解耦到不同文件夹中，在根目录进行组合，实现了清晰的逻辑边界和自动化的依赖调度。

### 目录结构
```plaintext
.
├── main.tf              # 环境编排“指挥官”，定义模块间的串联逻辑
├── variables.tf         # 全局变量定义
├── modules/
│   ├── core_container/  # 通用 Docker 容器管理模块（基础砖块）
│   ├── db/              # 数据库特化模块，负责 MySQL 启动与 IP 输出
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── app/             # 应用特化模块，接收外部 IP 并执行数据恢复
│       ├── main.tf
│       └── variables.tf
└── data/                # 存放 SQL 备份等静态资源
```

## 关键技术特性

1. **隐式依赖注入**：
   在 `main.tf` 中，`module.my_app` 引用了 `module.my_db.db_private_ip`。这建立了一个基于数据流的调度关系，Terraform 会自动确保数据库在应用启动前已准备就绪。

2. **Host 模式通讯优化**：
   针对 `network_mode = "host"` 的场景，系统内部通过私网 IP（或回环 IP）进行通讯，绕过防火墙限制，确保了连接的稳定性。

3. **完全幂等性**：
   - 只要配置和代码未变，再次运行 `apply` 不会产生任何副作用。
   - SQL 迁移工具通过文件 Hash 校验，仅在备份文件发生变化时才触发数据恢复。

4. **预热加速**：
   已配置远程 Docker 镜像加速（阿里云镜像源），大幅提升了首次部署的速度。

## 快速上手

### 前置要求
- 本地安装 Docker（推荐使用 OrbStack 或 Docker Desktop）。
- 本地有 SSH 访问远程服务器的权限。

### 执行部署
建议使用 Docker 化的 Terraform 运行，以保证环境一致性：

1. **初始化**：
   ```bash
   docker run --rm -v $(pwd):/workspace -v ~/.ssh:/root/.ssh -w /workspace hashicorp/terraform:latest init
   ```

2. **预览变更**：
   ```bash
   docker run --rm -v $(pwd):/workspace -v ~/.ssh:/root/.ssh -w /workspace hashicorp/terraform:latest plan
   ```

3. **执行部署**：
   ```bash
   docker run --rm -v $(pwd):/workspace -v ~/.ssh:/root/.ssh -w /workspace hashicorp/terraform:latest apply -auto-approve
   ```

## 维护说明
- **修改数据库配置**：直接编辑 `modules/db/main.tf` 或根目录的参数传递。
- **更新 SQL 数据**：替换 `data/host_data/` 下的文件，再次 `apply` 即可。

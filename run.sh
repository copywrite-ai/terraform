#!/bin/bash
################################################################################
# Terraform Docker Runner
################################################################################
# 
# 使用 Docker 容器运行 Terraform，确保环境一致性
# 
# 用法：
#   ./run.sh init      # 初始化
#   ./run.sh plan      # 预览变更
#   ./run.sh apply     # 应用变更
#   ./run.sh destroy   # 销毁资源
#   ./run.sh clean     # 清理本地 Terraform 缓存文件
#   ./run.sh <cmd>     # 任意 terraform 子命令
#
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ============================================================================
# 配置
# ============================================================================

# Terraform 镜像
TF_IMAGE="${TF_IMAGE:-docker.1ms.run/hashicorp/terraform:latest}"

# SSH 密钥目录（挂载到容器）
SSH_DIR="${SSH_DIR:-$HOME/.ssh}"

# 插件缓存目录（可选，加速后续运行）
PLUGIN_CACHE_DIR="${PLUGIN_CACHE_DIR:-$HOME/.terraform.d/plugin-cache}"

# ============================================================================
# 准备挂载卷
# ============================================================================

# 确保插件缓存目录存在
mkdir -p "$PLUGIN_CACHE_DIR"

# 挂载参数
VOLUMES=(
    # 项目目录
    -v "$SCRIPT_DIR:/workspace"
    # SSH 密钥（只读）
    -v "$SSH_DIR:/root/.ssh:ro"
    # 插件缓存（加速后续运行）
    -v "$PLUGIN_CACHE_DIR:/root/.terraform.d/plugin-cache"
    # Docker 套接字，允许容器内的 Terraform 控制宿主机 Docker
    -v /var/run/docker.sock:/var/run/docker.sock
)

# 如果存在当前目录或本地 .terraformrc 配置，则挂载
# 优先使用项目目录下的 .terraformrc，方便离线分发
if [ -f "$SCRIPT_DIR/.terraformrc" ]; then
    VOLUMES+=(-v "$SCRIPT_DIR/.terraformrc:/root/.terraformrc:ro")
    echo "ℹ️ Using local .terraformrc from project directory"
elif [ -f "$HOME/.terraformrc" ]; then
    VOLUMES+=(-v "$HOME/.terraformrc:/root/.terraformrc:ro")
    echo "ℹ️ Using global .terraformrc from $HOME"
fi

# 如果存在离线插件目录，挂载它
if [ -d "$SCRIPT_DIR/terraform-plugins" ]; then
    VOLUMES+=(-v "$SCRIPT_DIR/terraform-plugins:/terraform-plugins:ro")
fi

# ============================================================================
# 环境变量
# ============================================================================

ENV_VARS=(
    # 启用插件缓存
    -e "TF_PLUGIN_CACHE_DIR=/root/.terraform.d/plugin-cache"
    # 容器外的项目真实路径，用于处理 Docker-out-of-Docker 的挂载
    -e "HOST_PROJECT_DIR=$SCRIPT_DIR"
    -e "TF_VAR_host_project_dir=$SCRIPT_DIR"
)

# ============================================================================
# 运行 Terraform
# ============================================================================

echo "🚀 Running: terraform $*"
echo "   Image: $TF_IMAGE"
echo "   Workdir: $SCRIPT_DIR"
echo ""

if [ "$1" = "clean" ]; then
    echo "🧹 Cleaning local Terraform cache files"
    rm -rf "$SCRIPT_DIR/.terraform" "$SCRIPT_DIR/.terraform.lock.hcl"
    exit 0
fi

docker run --rm -it \
    --platform linux/amd64 \
    "${VOLUMES[@]}" \
    "${ENV_VARS[@]}" \
    -w /workspace \
    "$TF_IMAGE" \
    "$@"

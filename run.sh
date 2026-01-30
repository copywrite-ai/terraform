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
TF_IMAGE="${TF_IMAGE:-hashicorp/terraform:latest}"

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
)

# 如果存在本地 .terraformrc 配置，也挂载
if [ -f "$HOME/.terraformrc" ]; then
    VOLUMES+=(-v "$HOME/.terraformrc:/root/.terraformrc:ro")
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
    # 注意：不传递 SSH_AUTH_SOCK，因为 macOS 的 Unix socket 无法在 Linux 容器中使用
    # Terraform 会自动使用挂载的 /root/.ssh 目录中的密钥文件
)

# ============================================================================
# 运行 Terraform
# ============================================================================

echo "🚀 Running: terraform $*"
echo "   Image: $TF_IMAGE"
echo "   Workdir: $SCRIPT_DIR"
echo ""

docker run --rm -it \
    "${VOLUMES[@]}" \
    "${ENV_VARS[@]}" \
    -w /workspace \
    "$TF_IMAGE" \
    "$@"

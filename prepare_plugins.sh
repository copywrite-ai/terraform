#!/bin/bash
################################################################################
# 离线插件准备脚本
################################################################################
#
# 下载 Terraform Provider 到本地目录，用于离线/容器化运行
#
# 用法：./prepare_plugins.sh
#
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 插件输出目录
PLUGINS_DIR="$SCRIPT_DIR/terraform-plugins"

# Terraform 镜像
TF_IMAGE="${TF_IMAGE:-docker.1ms.run/hashicorp/terraform:latest}"

echo "📦 Downloading Terraform providers..."
echo "   Output: $PLUGINS_DIR"

mkdir -p "$PLUGINS_DIR"

# 创建临时 .terraformrc 使用阿里云镜像加速
cat > /tmp/tf_mirror.rc <<EOF
provider_installation {
  network_mirror {
    url = "https://mirrors.aliyun.com/terraform/"
  }
  direct {
    exclude = ["*/*"]
  }
}
EOF

docker run --rm \
    -v "$SCRIPT_DIR:/workspace" \
    -v /tmp/tf_mirror.rc:/root/.terraformrc:ro \
    -w /workspace \
    "$TF_IMAGE" \
    providers mirror \
    -platform=linux_amd64 \
    -platform=darwin_amd64 \
    -platform=darwin_arm64 \
    terraform-plugins

rm -f /tmp/tf_mirror.rc

echo ""
echo "✅ Plugins downloaded to: $PLUGINS_DIR"
echo ""
echo "📝 To use offline plugins, create .terraformrc with:"
echo ""
cat <<EOF
provider_installation {
  filesystem_mirror {
    path    = "/terraform-plugins"
    include = ["*/*"]
  }
  direct {
    exclude = ["*/*"]
  }
}
EOF

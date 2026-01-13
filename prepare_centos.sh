#!/bin/bash

# CentOS 离线 Provider 准备脚本
# 运行环境：有网络连接的 CentOS 机器，已安装 Docker

# 1. 创建工作目录
mkdir -p terraform-airgap
cd terraform-airgap

# 2. 创建 main.tf 文件，定义需要下载的 provider
cat <<EOF > main.tf
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
    # 在这里添加其他你需要的 provider
  }
}
EOF

# 3. 拉取 Terraform 镜像 (使用加速镜像)
docker pull docker.1ms.run/hashicorp/terraform:latest
docker tag docker.1ms.run/hashicorp/terraform:latest hashicorp/terraform:latest

# 4. (可选) 配置 Terraform 网络镜像 (如阿里云)
# 我们直接在当前目录创建一个临时配置文件，然后挂载到容器中
cat <<EOF > terraform_mirror.rc
provider_installation {
  network_mirror {
    url = "https://mirrors.aliyun.com/terraform/"
  }
  direct {
    exclude = ["*/*"]
  }
}
EOF

# 5. 初始化并下载 Provider 镜像到本地文件夹
mkdir -p terraform-plugins

# 如果下载缓慢，取消下面 HTTPS_PROXY 的注释并填写你的代理地址
# PROXY_ENV="-e HTTPS_PROXY=http://your-proxy-ip:port"

echo "正在从镜像源下载 Provider..."
docker run --rm $PROXY_ENV \
  -v $(pwd):/workspace \
  -v $(pwd)/terraform_mirror.rc:/root/.terraformrc \
  -w /workspace \
  hashicorp/terraform:latest \
  providers mirror \
  -platform=linux_amd64 \
  -platform=linux_arm64 \
  terraform-plugins

echo "----------------------------------------------------"
echo "所有 Provider 已准备就绪，存放在: \$(pwd)/terraform-plugins"
echo "你可以将整个 terraform-airgap 目录打包转移到离线环境。"

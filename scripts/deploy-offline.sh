#!/bin/bash
set -euo pipefail

# ============================================
# New-API 离线部署脚本（Docker + MySQL + New-API）
# 仓库：https://github.com/KaminDeng/new-api-helper
# 前提：支持从本仓库离线安装 Docker、加载 MySQL 镜像和 New-API 镜像
# 使用方法：bash deploy-offline.sh
# ============================================

# ---------- 可配置参数 ----------
MYSQL_ROOT_PASSWORD="StrongPass_123!"
MYSQL_DATABASE="oneapi"
MYSQL_USER="oneapi"
MYSQL_PASSWORD="StrongPass_123!"
NEW_API_PORT=3000
DATA_DIR="$HOME/new-api"
ARCH=$(uname -m)
SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
IMAGES_DIR="$REPO_ROOT/images"
DOCKER_TGZ="$IMAGES_DIR/docker-27.5.1.tgz"
MYSQL_TAR="$IMAGES_DIR/mysql-8.0.tar"
# --------------------------------

require_root() {
    if [[ ${EUID} -ne 0 ]]; then
        echo "错误：离线安装 Docker 需要 root 权限，请使用 sudo bash scripts/deploy-offline.sh 运行"
        exit 1
    fi
}

find_new_api_tar() {
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        NEW_API_IMAGE="calciumion/new-api:latest-arm64"
        echo "检测到 ARM64 架构"
        for f in \
            "$IMAGES_DIR/new-api-arm64.tar" \
            "$IMAGES_DIR/new-api-nightly-arm64.tar.gz" \
            "$PWD/new-api-arm64.tar" \
            "$PWD/new-api-nightly-arm64.tar.gz"; do
            if [ -f "$f" ]; then TAR_FILE="$f"; break; fi
        done
    else
        NEW_API_IMAGE="calciumion/new-api:latest"
        echo "检测到 AMD64 架构"
        for f in \
            "$IMAGES_DIR/new-api-amd64.tar" \
            "$IMAGES_DIR/new-api-nightly-amd64.tar.gz" \
            "$PWD/new-api-amd64.tar" \
            "$PWD/new-api-nightly-amd64.tar.gz"; do
            if [ -f "$f" ]; then TAR_FILE="$f"; break; fi
        done
    fi
}

install_docker_offline() {
    if command -v docker >/dev/null 2>&1; then
        echo "Docker 已安装，跳过离线安装"
        return
    fi

    require_root

    if [ ! -f "$DOCKER_TGZ" ]; then
        echo "错误：找不到 Docker 离线安装包：$DOCKER_TGZ"
        exit 1
    fi

    echo "安装 Docker 二进制包：$DOCKER_TGZ"
    tar -xzf "$DOCKER_TGZ" -C /tmp
    install -m 0755 /tmp/docker/* /usr/local/bin/
    rm -rf /tmp/docker

    if ! getent group docker >/dev/null 2>&1; then
        groupadd docker
    fi

    cat >/etc/systemd/system/docker.service <<'EOF'
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/local/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutStartSec=0
RestartSec=2
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    cat >/etc/systemd/system/docker.socket <<'EOF'
[Unit]
Description=Docker Socket for the API

[Socket]
ListenStream=/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
EOF

    mkdir -p /etc/docker
    cat >/etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

    systemctl daemon-reload
    systemctl enable --now docker.socket docker.service

    echo "Docker 离线安装完成"
}

echo "=== [1/6] 检查并离线安装 Docker ==="
install_docker_offline

echo ""
echo "=== [2/6] 加载 MySQL 镜像 ==="
if [ -f "$MYSQL_TAR" ]; then
    docker load -i "$MYSQL_TAR"
elif [ -f "$PWD/mysql-8.0.tar" ]; then
    docker load -i "$PWD/mysql-8.0.tar"
else
    echo "错误：找不到 mysql-8.0.tar，请确认存在于 images/ 或当前目录"
    exit 1
fi
echo "MySQL 镜像加载完成"

echo ""
echo "=== [3/6] 加载 New-API 镜像 ==="
find_new_api_tar

if [ -z "${TAR_FILE:-}" ]; then
    echo "错误：找不到 New-API 镜像 tar 文件，请确认存在于 images/ 或当前目录"
    exit 1
fi

docker load -i "$TAR_FILE"
echo "New-API 镜像加载完成（来源：$TAR_FILE）"

echo ""
echo "=== [4/6] 创建数据目录 ==="
mkdir -p "$DATA_DIR"

echo ""
echo "=== [5/6] 启动 MySQL 容器 ==="
docker rm -f new-api-mysql 2>/dev/null || true

docker run --name new-api-mysql -d --restart always \
    -p 3306:3306 \
    -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
    -e MYSQL_DATABASE="$MYSQL_DATABASE" \
    -e MYSQL_USER="$MYSQL_USER" \
    -e MYSQL_PASSWORD="$MYSQL_PASSWORD" \
    -v "$DATA_DIR/mysql-data":/var/lib/mysql \
    -e TZ=Asia/Shanghai \
    mysql:8.0 \
    --default-authentication-plugin=mysql_native_password \
    --character-set-server=utf8mb4 \
    --collation-server=utf8mb4_unicode_ci

echo "等待 MySQL 初始化完成..."
sleep 15

for i in {1..10}; do
    if docker exec new-api-mysql mysqladmin ping -u root -p"$MYSQL_ROOT_PASSWORD" --silent 2>/dev/null; then
        echo "MySQL 已就绪"
        break
    fi
    echo "等待 MySQL 启动... ($i/10)"
    sleep 3
done

echo ""
echo "=== [6/6] 启动 New-API 容器 ==="
docker rm -f new-api 2>/dev/null || true

docker run --name new-api -d --restart always \
    -p "$NEW_API_PORT":3000 \
    --add-host=host.docker.internal:host-gateway \
    -e "SQL_DSN=${MYSQL_USER}:${MYSQL_PASSWORD}@tcp(host.docker.internal:3306)/${MYSQL_DATABASE}?charset=utf8mb4&collation=utf8mb4_unicode_ci&parseTime=True&loc=Local" \
    -e TZ=Asia/Shanghai \
    -v "$DATA_DIR/data":/data \
    "$NEW_API_IMAGE"

echo ""
echo "========================================="
echo "  离线部署完成！"
echo ""
echo "  访问地址：http://$(hostname -I | awk '{print $1}'):${NEW_API_PORT}"
echo "  默认账号：root"
echo "  默认密码：123456"
echo ""
echo "  请立即登录并修改默认密码！"
echo "========================================="

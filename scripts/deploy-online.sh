#!/bin/bash
set -euo pipefail

# ============================================
# New-API 在线部署脚本（MySQL + New-API）
# 仓库：https://github.com/KaminDeng/new-api-helper
# 使用方法：bash deploy-online.sh
# ============================================

# ---------- 可配置参数 ----------
MYSQL_ROOT_PASSWORD="StrongPass_123!"
MYSQL_DATABASE="oneapi"
MYSQL_USER="oneapi"
MYSQL_PASSWORD="StrongPass_123!"
NEW_API_PORT=3000
DATA_DIR="$HOME/new-api"
ARCH=$(uname -m)
# --------------------------------

# 根据架构选择镜像标签
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    NEW_API_IMAGE="calciumion/new-api:latest-arm64"
    echo "检测到 ARM64 架构"
else
    NEW_API_IMAGE="calciumion/new-api:latest"
    echo "检测到 AMD64 架构"
fi

echo ""
echo "=== [1/5] 创建数据目录 ==="
mkdir -p "$DATA_DIR"
echo "数据目录：$DATA_DIR"

echo ""
echo "=== [2/5] 拉取 MySQL 镜像 ==="
docker pull mysql:8.0

echo ""
echo "=== [3/5] 启动 MySQL 容器 ==="
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
echo "=== [4/5] 拉取 New-API 镜像 ==="
docker pull "$NEW_API_IMAGE"

echo ""
echo "=== [5/5] 启动 New-API 容器 ==="
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
echo "  部署完成！"
echo ""
echo "  访问地址：http://$(hostname -I | awk '{print $1}'):${NEW_API_PORT}"
echo "  默认账号：root"
echo "  默认密码：123456"
echo ""
echo "  请立即登录并修改默认密码！"
echo "========================================="

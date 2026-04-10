#!/bin/bash
set -euo pipefail

# ============================================
# New-API 离线部署脚本（MySQL + New-API）
# 仓库：https://github.com/KaminDeng/new-api-helper
# 前提：同目录下有 mysql-8.0.tar 和 new-api 的 tar 包
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
# --------------------------------

echo "=== [1/5] 加载 MySQL 镜像 ==="
if [ ! -f "mysql-8.0.tar" ]; then
    echo "错误：找不到 mysql-8.0.tar，请确认文件在当前目录"
    exit 1
fi
docker load -i mysql-8.0.tar
echo "MySQL 镜像加载完成"

echo ""
echo "=== [2/5] 加载 New-API 镜像 ==="
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    NEW_API_IMAGE="calciumion/new-api:latest-arm64"
    echo "检测到 ARM64 架构"
    # 按优先级查找 tar 文件
    for f in new-api-arm64.tar new-api-nightly-arm64.tar.gz; do
        if [ -f "$f" ]; then TAR_FILE="$f"; break; fi
    done
else
    NEW_API_IMAGE="calciumion/new-api:latest"
    echo "检测到 AMD64 架构"
    for f in new-api-amd64.tar new-api-nightly-amd64.tar.gz; do
        if [ -f "$f" ]; then TAR_FILE="$f"; break; fi
    done
fi

if [ -z "${TAR_FILE:-}" ]; then
    echo "错误：找不到 New-API 镜像 tar 文件，请确认文件在当前目录"
    echo "当前目录文件："
    ls -lh *.tar *.tar.gz 2>/dev/null || echo "(无 tar 文件)"
    exit 1
fi

docker load -i "$TAR_FILE"
echo "New-API 镜像加载完成（来源：$TAR_FILE）"

echo ""
echo "=== [3/5] 创建数据目录 ==="
mkdir -p "$DATA_DIR"

echo ""
echo "=== [4/5] 启动 MySQL 容器 ==="
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
echo "  离线部署完成！"
echo ""
echo "  访问地址：http://$(hostname -I | awk '{print $1}'):${NEW_API_PORT}"
echo "  默认账号：root"
echo "  默认密码：123456"
echo ""
echo "  请立即登录并修改默认密码！"
echo "========================================="

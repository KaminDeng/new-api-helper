#!/bin/bash
set -euo pipefail

# ============================================
# 离线镜像导出脚本
# 仓库：https://github.com/KaminDeng/new-api-helper
# 在有网络的机器上执行，生成 tar 包后拷贝到内网
# 使用方法：bash export-images.sh
# ============================================

OUTPUT_DIR="${1:-.}"

echo "=== [1/3] 拉取镜像 ==="
docker pull mysql:8.0
docker pull calciumion/new-api:latest           # AMD64
docker pull calciumion/new-api:latest-arm64     # ARM64

echo ""
echo "=== [2/3] 导出 MySQL 镜像 ==="
docker save -o "$OUTPUT_DIR/mysql-8.0.tar" mysql:8.0
echo "已生成：$OUTPUT_DIR/mysql-8.0.tar ($(du -h "$OUTPUT_DIR/mysql-8.0.tar" | cut -f1))"

echo ""
echo "=== [3/3] 导出 New-API 镜像 ==="
docker save -o "$OUTPUT_DIR/new-api-amd64.tar" calciumion/new-api:latest
echo "已生成：$OUTPUT_DIR/new-api-amd64.tar ($(du -h "$OUTPUT_DIR/new-api-amd64.tar" | cut -f1))"

docker save -o "$OUTPUT_DIR/new-api-arm64.tar" calciumion/new-api:latest-arm64
echo "已生成：$OUTPUT_DIR/new-api-arm64.tar ($(du -h "$OUTPUT_DIR/new-api-arm64.tar" | cut -f1))"

echo ""
echo "========================================="
echo "  导出完成！请将以下文件拷贝到内网机器："
echo ""
ls -lh "$OUTPUT_DIR"/mysql-8.0.tar "$OUTPUT_DIR"/new-api-*.tar
echo ""
echo "  然后执行：bash deploy-offline.sh"
echo "========================================="

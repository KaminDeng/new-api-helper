# new-api-helper

New-API Docker 镜像分发与部署工具集，提供在线/离线一键部署方案。

> [New-API](https://github.com/Calcium-Ion/new-api) 是下一代 AI 模型网关，支持将 OpenAI / Claude / Gemini 等多种大模型 API 统一管理和分发。

## 仓库内容

```
├── scripts/
│   ├── deploy-online.sh      # 在线一键部署（自动拉取镜像）
│   ├── deploy-offline.sh     # 离线一键部署（从 tar 包加载）
│   └── export-images.sh      # 镜像导出（联网机器上执行）
├── docs/blog/
│   └── blog-cn.md            # 完整部署教程
├── images/
│   ├── docker-27.5.1.tgz         # Docker 离线安装包
│   ├── mysql-8.0.tar             # MySQL 离线镜像
│   ├── new-api-nightly-amd64.tar.gz
│   └── new-api-nightly-arm64.tar.gz
└── docs/blog/blog-cn.md          # 完整部署教程
```

## 快速开始

### 在线部署（联网环境）

```bash
git clone https://github.com/KaminDeng/new-api-helper.git
cd new-api-helper
bash scripts/deploy-online.sh
```

### 离线部署（完全无网环境）

如果目标机器**没有外网**，甚至**还没安装 Docker**，本仓库也可以直接离线部署。

**方案 A：直接使用仓库内置离线资源**

仓库已包含以下离线文件：

- `images/docker-27.5.1.tgz`：Docker 二进制离线安装包
- `images/mysql-8.0.tar`：MySQL 镜像 tar 包
- `images/new-api-nightly-amd64.tar.gz` / `images/new-api-nightly-arm64.tar.gz`：New-API 镜像包

直接执行：

```bash
sudo bash scripts/deploy-offline.sh
```

**方案 B：在联网机器上重新导出镜像**

```bash
bash scripts/export-images.sh
```

然后将 `images/` 目录或导出的 tar 文件与 `scripts/deploy-offline.sh` 一起拷贝到目标机器，再执行：

```bash
sudo bash deploy-offline.sh
```

### 部署完成后

- 访问 `http://<服务器IP>:3000`
- 默认账号：`root` / `123456`
- **请立即修改默认密码**

## 配置说明

编辑脚本顶部的参数区域即可自定义：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `MYSQL_ROOT_PASSWORD` | `StrongPass_123!` | MySQL root 密码 |
| `MYSQL_DATABASE` | `oneapi` | 数据库名 |
| `MYSQL_USER` | `oneapi` | 数据库用户名 |
| `MYSQL_PASSWORD` | `StrongPass_123!` | 数据库用户密码 |
| `NEW_API_PORT` | `3000` | New-API 服务端口 |
| `DATA_DIR` | `$HOME/new-api` | 数据持久化目录 |

## 离线部署说明

离线脚本会自动完成以下步骤：

1. 检查系统是否已安装 Docker
2. 若未安装，则从 `images/docker-27.5.1.tgz` 离线安装 Docker
3. 从 `images/mysql-8.0.tar` 或当前目录加载 MySQL 镜像
4. 根据架构自动选择并加载对应的 New-API 镜像
5. 启动 MySQL 容器并等待就绪
6. 启动 New-API 容器

> 注意：首次在纯离线机器上执行时，请使用 `sudo bash scripts/deploy-offline.sh`，因为安装 Docker 和写入 systemd 服务需要 root 权限。

## 架构支持

脚本自动检测系统架构并选择对应镜像：

- **AMD64** (x86_64) — `calciumion/new-api:latest`
- **ARM64** (aarch64) — `calciumion/new-api:latest-arm64`

## 详细教程

完整的部署教程和常见问题排查请参考 [部署指南](docs/blog/blog-cn.md)。

## 相关链接

- [New-API 上游仓库](https://github.com/Calcium-Ion/new-api)
- [New-API 官方文档](https://docs.newapi.pro/)
- [Docker Hub](https://hub.docker.com/r/calciumion/new-api)

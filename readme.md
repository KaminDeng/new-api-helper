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
├── new-api-nightly-amd64.tar.gz   # 预导出镜像（AMD64）
└── new-api-nightly-arm64.tar.gz   # 预导出镜像（ARM64）
```

## 快速开始

### 在线部署（联网环境）

```bash
git clone https://github.com/KaminDeng/new-api-helper.git
cd new-api-helper
bash scripts/deploy-online.sh
```

### 离线部署（内网环境）

**Step 1** — 在联网机器上导出镜像：

```bash
bash scripts/export-images.sh
```

**Step 2** — 将 tar 文件和 `scripts/deploy-offline.sh` 拷贝到内网机器。

**Step 3** — 在内网机器上执行：

```bash
bash deploy-offline.sh
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

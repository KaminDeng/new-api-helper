# New-API 完整部署指南：在线 & 离线环境一文搞定（MySQL + Docker）

> **本仓库**：[https://github.com/KaminDeng/new-api-helper](https://github.com/KaminDeng/new-api-helper)
> 
> **New-API 上游仓库**：[https://github.com/Calcium-Ion/new-api](https://github.com/Calcium-Ion/new-api)
> 
> **官方文档**：[https://docs.newapi.pro/](https://docs.newapi.pro/)
> 
> **Docker Hub**：[https://hub.docker.com/r/calciumion/new-api](https://hub.docker.com/r/calciumion/new-api)

---

## 一、你是不是也遇到了这些问题？

| 痛点 | 场景 |
|------|------|
| 手里有 OpenAI / Claude / Gemini 等多家 API Key，管理起来一团糟 | 个人开发者 |
| 公司内部想统一分发 AI 接口，需要配额管理和计费 | 企业 IT |
| 服务器在内网，没有外网访问权限，但又想部署 AI 网关 | 政企 / 安全敏感环境 |
| 想把 Claude 格式转成 OpenAI 格式统一调用 | 多模型应用开发 |

如果你中了任意一条，**New-API** 就是你要找的工具。它是基于 One API 二次开发的下一代 AI 模型网关，支持将多种大模型 API 转换为 OpenAI / Claude / Gemini 兼容格式，一个后台管理所有渠道、用户、配额和计费。

---

## 二、New-API 能做什么？

| 功能 | 说明 |
|------|------|
| 协议转换 | OpenAI ↔ Claude ↔ Gemini 格式互转 |
| 多渠道管理 | 统一管理 OpenAI、Claude、Gemini、通义千问、文心一言等 |
| Midjourney / Suno | 支持 Midjourney Proxy 图片生成、Suno 音乐生成 |
| 用户 & 配额 | 多用户管理、按量计费、分级定价 |
| 负载均衡 | 加权随机路由，自动故障转移 |
| 流式代理 | 完整支持 SSE 流式输出 |
| Claude Thinking | 模型名加 `-thinking` 后缀即可开启思考模式 |
| 多数据库 | SQLite / MySQL ≥ 5.7.8 / PostgreSQL ≥ 9.6 |

---

## 三、部署架构概览

本文覆盖两种部署方式，你可以根据网络环境选择：

```
┌─────────────────────────────────────────────┐
│              部署方案选择                      │
├──────────────────┬──────────────────────────┤
│   在线部署        │   离线部署（内网/气隙）     │
│   docker pull     │   docker save / load     │
│   直接拉取镜像     │   U盘/SCP 拷贝 tar 包    │
├──────────────────┴──────────────────────────┤
│              共同依赖                         │
│   Docker Engine + MySQL 5.7+                 │
└─────────────────────────────────────────────┘
```

**最终部署拓扑**：

```
[客户端/浏览器] → :3000 → [New-API 容器] → MySQL 容器(:3306)
                                         → [上游 AI API]
```

---

## 四、前置准备

确保目标机器上已安装 Docker。

```bash
# 检查 Docker 是否可用
docker --version
# 期望输出类似：Docker version 24.x.x

# 如果没有安装 Docker，在线环境执行：
curl -fsSL https://get.docker.com | bash
sudo systemctl enable --now docker
```

---

## 五、在线部署（联网环境）

适用于服务器可以直接访问 Docker Hub 的场景。

### 5.1 一键部署

本仓库提供了一键部署脚本，克隆后直接运行：

```bash
git clone https://github.com/KaminDeng/new-api-helper.git
cd new-api-helper
bash scripts/deploy-online.sh
```

脚本会自动完成以下工作：

1. 检测系统架构（AMD64 / ARM64）
2. 拉取 MySQL 8.0 镜像并启动
3. 等待 MySQL 就绪
4. 拉取 New-API 镜像并启动
5. 输出访问地址

> 如需修改数据库密码、端口等参数，编辑 `scripts/deploy-online.sh` 顶部的配置区域即可。

### 5.2 手动分步部署

如果你更喜欢手动操作，按以下步骤执行：

**第一步：启动 MySQL**

```bash
docker pull mysql:8.0

docker run --name new-api-mysql -d --restart always \
    -p 3306:3306 \
    -e MYSQL_ROOT_PASSWORD="StrongPass_123!" \
    -e MYSQL_DATABASE="oneapi" \
    -e MYSQL_USER="oneapi" \
    -e MYSQL_PASSWORD="StrongPass_123!" \
    -v ~/new-api/mysql-data:/var/lib/mysql \
    -e TZ=Asia/Shanghai \
    mysql:8.0 \
    --default-authentication-plugin=mysql_native_password \
    --character-set-server=utf8mb4 \
    --collation-server=utf8mb4_unicode_ci
```

等待 15 秒让 MySQL 完成初始化。

**第二步：启动 New-API**

```bash
# AMD64 架构
docker pull calciumion/new-api:latest

# ARM64 架构（如树莓派、Mac M 系列等）
# docker pull calciumion/new-api:latest-arm64

docker run --name new-api -d --restart always \
    -p 3000:3000 \
    --add-host=host.docker.internal:host-gateway \
    -e 'SQL_DSN=oneapi:StrongPass_123!@tcp(host.docker.internal:3306)/oneapi?charset=utf8mb4&collation=utf8mb4_unicode_ci&parseTime=True&loc=Local' \
    -e TZ=Asia/Shanghai \
    -v ~/new-api/data:/data \
    calciumion/new-api:latest
```

**第三步：验证**

```bash
# 查看容器运行状态
docker ps -a

# 查看 New-API 日志
docker logs -f new-api
```

浏览器访问 `http://<服务器IP>:3000`，使用默认账号 `root` / `123456` 登录。

---

## 六、离线部署（内网 / 气隙环境）

适用于生产服务器无法访问外网的场景。现在脚本还支持**完全离线**的机器：即目标服务器既没有外网，也还没安装 Docker，也可以直接安装并部署。

### 6.1 在联网机器上：导出镜像

本仓库提供了镜像导出脚本；同时仓库内也可以直接放置离线安装资源（如 `images/docker-27.5.1.tgz`、`images/mysql-8.0.tar`、`images/new-api-nightly-*.tar.gz`），用于完全无网环境。

```bash
git clone https://github.com/KaminDeng/new-api-helper.git
cd new-api-helper
bash scripts/export-images.sh
```

脚本会拉取 MySQL 8.0 和 New-API（AMD64 + ARM64）的镜像，并导出为 tar 文件。

> 也可以直接使用本仓库 [Releases](https://github.com/KaminDeng/new-api-helper/releases) 页面预构建的 tar 包，免去自行导出的步骤。

### 6.2 传输文件到内网

将以下文件通过 U 盘、SCP 或其他安全方式传输到目标内网机器：

```
images/docker-27.5.1.tgz         # Docker 离线安装包
images/mysql-8.0.tar             # MySQL 镜像
images/new-api-amd64.tar         # New-API 镜像（AMD64，可选）
images/new-api-arm64.tar         # New-API 镜像（ARM64，可选）
images/new-api-nightly-amd64.tar.gz
images/new-api-nightly-arm64.tar.gz
scripts/deploy-offline.sh        # 离线部署脚本
```

### 6.3 在内网机器上：一键部署

推荐保持仓库目录结构不变，直接执行：

```bash
sudo bash scripts/deploy-offline.sh
```

如果你只拷贝了脚本和镜像文件，也可以保证 `images/` 目录与脚本路径关系不变后执行。

脚本会自动完成以下工作：

1. 检查系统是否已安装 Docker
2. 如果没有安装，则从 `images/docker-27.5.1.tgz` 离线安装 Docker
3. 加载 MySQL 镜像（从 `images/mysql-8.0.tar` 或当前目录）
4. 检测系统架构，加载对应的 New-API 镜像（兼容 `images/new-api-nightly-*.tar.gz` 命名格式）
5. 启动 MySQL 容器并等待就绪
6. 启动 New-API 容器
7. 输出访问地址

> 同样，数据库密码等参数在脚本顶部的配置区域修改。

---

## 七、部署后配置

### 7.1 登录管理后台

浏览器打开 `http://<服务器IP>:3000`，默认账号密码：

- 用户名：`root`
- 密码：`123456`

> **首次登录后请立即修改密码！**

### 7.2 添加 AI 渠道

1. 进入「渠道管理」
2. 点击「添加新的渠道」
3. 选择渠道类型（OpenAI / Claude / Gemini 等）
4. 填入你的 API Key
5. 测试连通性后保存

### 7.3 创建 API Token

1. 进入「令牌管理」
2. 点击「添加新的令牌」
3. 设置令牌名称、额度限制、可用模型
4. 生成后即可使用该 Token 调用接口

### 7.4 调用示例

```bash
# 将 NEW_API_TOKEN 替换为你创建的令牌
curl http://<服务器IP>:3000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer NEW_API_TOKEN" \
    -d '{
        "model": "gpt-4o",
        "messages": [{"role": "user", "content": "Hello!"}],
        "stream": true
    }'
```

---

## 八、常用运维命令

```bash
# 查看所有容器状态
docker ps -a

# 查看 New-API 日志
docker logs -f new-api

# 查看 MySQL 日志
docker logs -f new-api-mysql

# 重启 New-API
docker restart new-api

# 停止并删除所有容器（数据保留在 ~/new-api/ 目录）
docker rm -f new-api new-api-mysql

# 更新镜像（在线环境）
docker pull calciumion/new-api:latest
docker rm -f new-api
# 重新执行 docker run 命令启动
```

---

## 九、常见问题

| 问题 | 解决方案 |
|------|----------|
| New-API 启动后立即退出 | `docker logs new-api` 查看日志，通常是 MySQL 连接失败，检查 SQL_DSN 配置 |
| 无法连接 MySQL | 确认 MySQL 容器已启动且就绪；检查 `--add-host` 参数是否正确 |
| ARM64 机器镜像不匹配 | 确保使用 `latest-arm64` 标签的镜像 |
| 离线加载 tar 失败 | 确认 tar 文件完整（未被截断），可用 `file xxx.tar` 或 `file xxx.tgz` 检查文件类型 |
| 纯离线机器没有 Docker | 使用 `sudo bash scripts/deploy-offline.sh`，脚本会从 `images/docker-27.5.1.tgz` 自动安装 Docker |
| 端口 3000 被占用 | 修改脚本中的 `NEW_API_PORT` 变量，或在 docker run 中改为 `-p 其他端口:3000` |
| 数据库迁移（SQLite → MySQL） | 参考官方文档：[docs.newapi.pro](https://docs.newapi.pro/) |

---

## 十、总结

| 对比项 | 在线部署 | 离线部署 |
|--------|---------|---------|
| 网络要求 | 需要访问 Docker Hub | 不需要外网 |
| 准备工作 | 几乎为零 | 需要在联网机器提前导出镜像 |
| 适用场景 | 开发/测试环境 | 生产/内网/安全敏感环境 |
| 更新方式 | `docker pull` 直接更新 | 重新导出 → 传输 → 加载 |
| 部署时间 | 约 5 分钟 | 约 10 分钟（不含传输时间） |

两种方式最终效果完全一致，选择适合你网络环境的方案即可。

---

> **本仓库**：[https://github.com/KaminDeng/new-api-helper](https://github.com/KaminDeng/new-api-helper)
> 
> **New-API 上游仓库**：[https://github.com/Calcium-Ion/new-api](https://github.com/Calcium-Ion/new-api)
> 
> **官方文档**：[https://docs.newapi.pro/](https://docs.newapi.pro/)
> 
> **Docker Hub**：[https://hub.docker.com/r/calciumion/new-api](https://hub.docker.com/r/calciumion/new-api)

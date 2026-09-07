# 拼多多自动回复系统 —— Zeabur 部署完整指南

本指南详细介绍如何将拼多多自动回复系统（`pdd-auto-reply`）部署到 [Zeabur](https://zeabur.com) PaaS 平台。

---

## 目录
- [一、部署架构与核心原则](#一部署架构与核心原则)
- [二、部署方案 A：Zeabur CLI 一键部署（推荐）](#二部署方案-a-zeabur-cli-一键部署推荐)
- [三、部署方案 B：Zeabur 控制台手动配置](#三部署方案-b-zeabur-控制台手动配置)
- [四、持久化存储配置（Volumes）](#四持久化存储配置volumes)
- [五、域名与网络配置](#五域名与网络配置)
- [六、环境变量速查表](#六环境变量速查表)
- [七、常见问题与排障（FAQ）](#七常见问题与排障faq)

---

## 一、部署架构与核心原则

本项目包含 6 个协同运行的服务：

| 服务名 | 部署类型 | 端口 | 暴露范围 | 说明 |
|---|---|---|---|---|
| `mysql` | Marketplace Prebuilt | 3306 | 仅内网 | MySQL 8.0 业务数据库，自动持久化 |
| `redis` | Marketplace Prebuilt | 6379 | 仅内网 | Redis 7 缓存与分布式锁 |
| `backend` | Git (Dockerfile) | 8089 | 仅内网 | FastAPI HTTP API，负责启动自检与数据迁移 |
| `websocket` | Git (Dockerfile) | 8090 | 仅内网 | 拼多多通道与 Playwright 浏览器会话 |
| `scheduler` | Git (Dockerfile) | 8091 | 仅内网 | 定时任务调度器（Cookie刷新/商品同步等） |
| `frontend` | Git (Dockerfile) | 80 | **公网** | Vue 3 + Nginx，反代 API 与 WebSocket，唯一公网入口 |

### ⚠️ 关键原则（务必遵守）
1. **构建上下文（Build Context）必须在根目录**：
   `backend`、`websocket`、`scheduler` 均需依赖根目录下的 `common/` 公共库。
   在 Zeabur 创建 Git 服务时，**Root Directory 必须保持留空（即 `/`）**，通过环境变量 `ZBPACK_DOCKERFILE_PATH` 来指定子目录下的 Dockerfile。
2. **云端容器必须开启无头模式**：
   在 `websocket` 服务的环境变量中必须设置 `BROWSER_HEADLESS=true`，否则 Chromium 启动因缺少显示服务而崩溃。
3. **服务间通信全走内网**：
   Zeabur 同项目内服务默认通过 `<服务名>.zeabur.internal` 互联，通信安全无公网流量费用。

---

## 二、部署方案 A：Zeabur CLI 一键部署（推荐）

本项目根目录下已内置标准的 [`template.yaml`](../template.yaml) 模板定义。

### 步骤：
1. 确保已将最新代码推送到 GitHub 仓库；
2. 安装并登录 Zeabur CLI：
   ```bash
   npx zeabur@latest login
   ```
3. 执行一键部署：
   ```bash
   npx zeabur@latest template deploy -f template.yaml
   ```
4. 部署提示输入各变量（JWT_SECRET_KEY、DATA_ENCRYPT_KEY 等密钥及管理员密码）后，Zeabur 将自动创建全套 6 个服务及其依赖关系。

---

## 三、部署方案 B：Zeabur 控制台手动配置

### 步骤 1：创建项目与基础服务
1. 打开 [Zeabur Dashboard](https://dash.zeabur.com)，点击 **Create Project**（建议命名为 `pdd-auto-reply`，Region 优先推荐 **Asia-East / Hong Kong**）；
2. 点击 **Create Service** -> 选择 **Marketplace** -> 搜索安装 **MySQL**（服务名保持 `mysql`）；
3. 点击 **Create Service** -> 选择 **Marketplace** -> 搜索安装 **Redis**（服务名保持 `redis`）；
4. 进入 MySQL 服务设置，在 Variables 中确认或添加 `MYSQL_DATABASE=pdd_auto_reply`。

---

### 步骤 2：部署 3 个 Python 服务

#### 1) backend 服务
1. 点击 **Create Service** -> **Git** -> 选择本仓库；
2. 将服务重命名为 `backend`；
3. 进入 **Settings**：
   - **Root Directory**：保持留空（即 `/`）；
   - **Watch Paths**（可选）：`backend/**, common/**`；
4. 进入 **Storage**（存储）：
   - 点击 **Add Volume**，挂载路径设为：`/app/backend/static`；
5. 进入 **Variables**，点击 **Edit as Raw**，参考 [`.env.zeabur.example`](../.env.zeabur.example) 粘贴 `backend` 相关变量。

#### 2) websocket 服务
1. 点击 **Create Service** -> **Git** -> 选择本仓库；
2. 重命名为 `websocket`；
3. 进入 **Settings**：
   - **Root Directory**：保持留空（即 `/`）；
   - **Watch Paths**（可选）：`websocket/**, common/**`；
4. 进入 **Storage**（存储）：
   - 点击 **Add Volume**，挂载路径设为：`/app/websocket/browser_data`；
5. 进入 **Variables**，点击 **Edit as Raw**，粘贴 `websocket` 变量，确保包含：
   - `ZBPACK_DOCKERFILE_PATH=websocket/Dockerfile`
   - `BROWSER_HEADLESS=true`

#### 3) scheduler 服务
1. 点击 **Create Service** -> **Git** -> 选择本仓库；
2. 重命名为 `scheduler`；
3. 进入 **Settings**：
   - **Root Directory**：保持留空（即 `/`）；
   - **Watch Paths**（可选）：`scheduler/**, common/**`；
4. 进入 **Variables**，点击 **Edit as Raw**，粘贴 `scheduler` 变量，确保设置：
   - `ZBPACK_DOCKERFILE_PATH=scheduler/Dockerfile`

---

### 步骤 3：部署前端服务（frontend）

1. 点击 **Create Service** -> **Git** -> 选择本仓库；
2. 重命名为 `frontend`；
3. 进入 **Settings**：
   - **Root Directory**：保持留空（即 `/`）；
   - **Watch Paths**（可选）：`frontend/**`；
4. 进入 **Variables**，设置：
   - `ZBPACK_DOCKERFILE_PATH=frontend/Dockerfile`
   - `BACKEND_API_URL=http://backend.zeabur.internal:8089`
5. 进入 **Networking**：
   - 点击 **Generate Domain** 分配一个免费的 `*.zeabur.app` 域名，或点击 **Custom Domain** 绑定您自己的域名。

---

## 四、持久化存储配置（Volumes）

为了防止容器重启导致数据丢失，请务必确认以下挂载点已配置：

| 服务名 | 挂载路径 | 作用 |
|---|---|---|
| `backend` | `/app/backend/static` | 存储上传的图片、静态附件 |
| `websocket` | `/app/websocket/browser_data` | 存储 Playwright 浏览器用户数据与登录 Session |

---

## 五、域名与网络配置

1. **公网暴露**：
   整个项目中**仅有 frontend** 需要在 **Networking** 面板中生成或绑定公网域名。
2. **Nginx 路由原理**：
   用户通过公网域名访问 `frontend` 时：
   - 普通网页路由 `/` 由 Nginx 直接提供静态资源；
   - API 请求 `/api/*` 由 Nginx 自动转发至 `http://backend.zeabur.internal:8089/api/v1/*`；
   - 在线客服推送 `/api/v1/chat/ws` 由 Nginx 自动升级协议转发到后端的 WebSocket 端口；
   - 上传图片 `/static/*` 由 Nginx 代理到后端的静态文件路径。

---

## 六、环境变量速查表（采用 Zeabur 变量引用语法）

详见项目根目录下的参考文件：[`.env.zeabur.example`](../.env.zeabur.example)。

Zeabur 提供了强大的 `${VARIABLE_NAME}` 变量引用能力：
1. **跨服务引用**：同项目内任意服务勾选 Expose 的变量，其他服务均可使用 `${KEY}` 直接引用；
2. **预置服务变量**：Marketplace 创建的 MySQL / Redis 变量可直接引用（如 `${MYSQL_HOST}`、`${MYSQL_PASSWORD}`、`${REDIS_PASSWORD}` 等）；
3. **内网主机名**：每个服务内置提供 `${<SERVICE>_HOST}`，如 `${BACKEND_HOST}` 自动解析为 `backend.zeabur.internal`。

### 核心引用示例：
```ini
# 数据库与缓存（直接引用 MySQL 和 Redis 服务的参数）
MYSQL_HOST=${MYSQL_HOST}
MYSQL_PORT=${MYSQL_PORT}
MYSQL_USER=${MYSQL_USERNAME}
MYSQL_PASSWORD=${MYSQL_PASSWORD}
MYSQL_DATABASE=${MYSQL_DATABASE}

REDIS_HOST=${REDIS_HOST}
REDIS_PORT=${REDIS_PORT}
REDIS_PASSWORD=${REDIS_PASSWORD}

# 服务内部通信（直接引用各服务的主机名与端口）
BACKEND_WEB_SERVICE_URL=http://${BACKEND_HOST}:8089
WEBSOCKET_SERVICE_URL=http://${WEBSOCKET_HOST}:8090
SCHEDULER_SERVICE_URL=http://${SCHEDULER_HOST}:8091

# 前端反代后端目标
BACKEND_API_URL=http://${BACKEND_HOST}:8089

# 在 websocket 和 scheduler 中直接引用 backend 暴露的安全密钥
JWT_SECRET_KEY=${JWT_SECRET_KEY}
DATA_ENCRYPT_KEY=${DATA_ENCRYPT_KEY}
INTERNAL_SERVICE_TOKEN=${INTERNAL_SERVICE_TOKEN}
```

---

## 七、常见问题与排障（FAQ）

### 1. 构建时报错 `COPY failed: file not found in build context: common`
* **原因**：在服务设置里将 Root Directory 填成了 `backend` 等子目录。
* **解决**：进入该服务的 Settings，清空 **Root Directory**（保持根目录），并确保环境变量中添加了 `ZBPACK_DOCKERFILE_PATH=<服务名>/Dockerfile`。

### 2. `websocket` 启动后 Chromium 崩溃抛出 `TargetClosedError`
* **原因**：云端无物理显示器或 X11 Server，使用了非无头模式。
* **解决**：在 `websocket` 环境变量中设置 `BROWSER_HEADLESS=true`。

### 3. 拼多多后台提示网络异常或验证码频繁
* **原因**：海外机房 IP 遭到拼多多风控检测。
* **解决**：
  1. Project 优先创建在中国香港（Hong Kong）节点；
  2. 在系统设置或环境变量中启用住宅/高匿名代理：
     ```ini
     PROXY_ENABLED=true
     PROXY_API_URL=http://user:password@ip:port
     ```

### 4. 首次部署数据库表何时生成？
* `backend` 服务在启动生命周期（Lifespan）中内置了 `SchemaMigrator` 启动自检迁移器，会自动检测数据库并创建全部表结构、初始字典，以及初始管理员账号（`DEFAULT_ADMIN_USERNAME` / `DEFAULT_ADMIN_PASSWORD`）。
* 首次登录成功后，请尽快在系统的「个人设置」中修改超级管理员密码。


# Bestie-Check 配置与发布指南

本文档说明如何配置和测试 Bestie-Check 的后端代理服务（Gemini），以及如何准备正式发布。

---

## 📋 第一次配置

### 1. 配置后端服务

```bash
# 进入 backend 目录
cd backend

# 复制环境变量模板
cp .env.example .env

# 编辑 .env 文件，填入你的 Gemini API Key
# 打开 .env 文件，将 GEMINI_API_KEY 改为你的实际 API Key
# 例如：GEMINI_API_KEY=AIzaSyxxxxxxxxxxxxx

# 安装依赖
npm install

# 启动后端服务
npm start
```

后端服务将在 `http://localhost:8080` 启动。你应该看到类似以下的输出：

```
🚀 Bestie-Check Backend running on http://0.0.0.0:8080
📡 Health check: http://localhost:8080/health
🔑 API Key configured: Yes
```

### 2. 配置 iOS App（真机调试）

如果你使用**真机**进行调试，需要修改 `AIClient.swift` 中的 base URL：

1. 查找你的电脑 IP 地址：
   - **方法一（终端）**：运行 `ipconfig getifaddr en0`（Wi-Fi）或 `ipconfig getifaddr en1`（以太网）
   - **方法二（图形界面）**：系统设置 → 网络 → Wi-Fi → 详情 → IP 地址

2. 打开 `Bestie-Check/Services/AIClient.swift`

3. 找到 `backendProxyBaseURL` 属性，在真机调试的分支中修改：

```swift
#else
// 真机调试时，需要改为你电脑的 IP 地址
// 例如：return "http://192.168.1.100:8080"
return "http://192.168.1.100:8080"  // ⚠️ 改为你的电脑 IP
#endif
```

**注意**：如果使用**模拟器**，不需要修改，直接使用 `http://localhost:8080` 即可。

---

## 🔄 每次测试是否要重新配置？

**不需要！** 日常开发流程：

1. 启动后端服务：
   ```bash
   cd backend
   npm start
   ```

2. 在 Xcode 中运行 App（模拟器或真机）

3. 测试功能

**只有在以下情况才需要重新配置：**
- 换了电脑或换了 WiFi 网络（需要更新 IP 地址）
- 更换了 Gemini API Key（需要更新 `.env` 文件）
- 第一次在新电脑上设置

---

## 🌐 如何查看电脑 IP 地址

### macOS

**方法一：终端命令**
```bash
# Wi-Fi 连接
ipconfig getifaddr en0

# 以太网连接
ipconfig getifaddr en1

# 查看所有网络接口
ifconfig | grep "inet "
```

**方法二：系统设置**
1. 打开「系统设置」
2. 点击「网络」
3. 选择「Wi-Fi」或「以太网」
4. 点击「详情...」
5. 在「TCP/IP」标签页查看「IPv4 地址」

### Windows

**方法一：命令提示符**
```cmd
ipconfig
```
查找「IPv4 地址」字段

**方法二：图形界面**
1. 打开「设置」→「网络和 Internet」
2. 点击「属性」
3. 查看「IPv4 地址」

---

## 🚀 正式发布后

用户无法连接到你的本地电脑，因此必须将后端服务部署到公网。

### 1. 部署后端服务

你可以选择以下任一平台部署：

#### 选项 A：Railway（推荐，简单）

1. 访问 [Railway.app](https://railway.app)
2. 使用 GitHub 登录
3. 创建新项目 → 「Deploy from GitHub repo」
4. 选择你的仓库
5. 在「Variables」中添加环境变量：
   - `GEMINI_API_KEY`: 你的 API Key
   - `PORT`: `8080`（Railway 会自动分配端口，但可以设置）
   - `GEMINI_MODEL`: `gemini-1.5-flash`（可选）
6. Railway 会自动部署并提供 HTTPS URL，例如：`https://bestie-check-backend.railway.app`

#### 选项 B：Vercel（适合 Serverless）

1. 安装 Vercel CLI：`npm i -g vercel`
2. 在 `backend/` 目录运行：`vercel`
3. 按照提示配置
4. 在 Vercel Dashboard 添加环境变量 `GEMINI_API_KEY`
5. 注意：Vercel 是 Serverless，需要调整代码结构（可能需要使用 Vercel Functions）

#### 选项 C：自建服务器（VPS）

1. 在服务器上安装 Node.js（>= 18）
2. 克隆代码到服务器
3. 配置 `.env` 文件（包含 `GEMINI_API_KEY`）
4. 使用 PM2 或 systemd 运行服务：
   ```bash
   npm install -g pm2
   pm2 start server.js --name bestie-check-backend
   ```
5. 配置 Nginx 反向代理和 HTTPS（Let's Encrypt）

### 2. 修改 iOS App 的生产环境 URL

部署完成后，修改 `AIClient.swift` 中的 `productionBaseURL`：

```swift
#else
// Release 模式：使用生产环境的 HTTPS 地址
// 正式发布时，请将下面的地址改为你部署的后端服务的公网地址
return "https://bestie-check-backend.railway.app"  // ⚠️ 改为你的实际后端地址
#endif
```

**重要**：
- 确保使用 **HTTPS**（不是 HTTP）
- URL 不包含路径（例如：`https://your-backend.com`，不是 `https://your-backend.com/api/face-analysis`）
- 路径 `/api/face-analysis` 会在代码中自动拼接

### 3. 构建 Release 版本

1. 在 Xcode 中选择「Any iOS Device」或「Generic iOS Device」
2. Product → Archive
3. 上传到 App Store Connect

---

## 🔒 安全注意事项

1. **不要提交 API Key**：
   - 确保 `.env` 文件在 `.gitignore` 中（例如 `backend/.env`）
   - 确保不要将 API Key 硬编码到代码中

2. **生产环境**：
   - 使用 HTTPS
   - 考虑限制 CORS 来源（修改 `server.js` 中的 CORS 配置）
   - 考虑添加 API 限流（Rate Limiting）

3. **API Key 管理**：
   - 定期轮换 API Key
   - 在部署平台使用环境变量，不要硬编码

---

## 📝 总结

- **开发测试**：本地运行 `npm start`，App 连接 `localhost`（模拟器）或电脑 IP（真机）
- **正式发布**：部署后端到公网，修改 `productionBaseURL` 为 HTTPS 地址
- **配置频率**：只在换电脑/换网络/换 Key 时重新配置

如有问题，请参考 `backend/README.md` 或查看项目文档。

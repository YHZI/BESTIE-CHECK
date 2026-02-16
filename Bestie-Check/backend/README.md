# Bestie-Check Backend Proxy

这是一个 Node.js + Express 后端代理服务，用于 Bestie-Check iOS App。它将人脸分析数据转发到 OpenAI API，并返回简短的评价文本。

## 快速开始

### 1. 安装依赖

```bash
cd backend
npm install
```

### 2. 配置环境变量

```bash
cp .env.example .env
```

然后编辑 `.env` 文件，填入你的 OpenAI API Key：

```
OPENAI_API_KEY=sk-your-actual-api-key-here
```

**重要：** `.env` 文件不会被提交到 git，请确保不要泄露你的 API Key。

### 3. 启动服务

```bash
npm start
```

服务将在 `http://localhost:8080` 启动。

## API 端点

### POST /api/face-analysis

接收 iOS App 发送的人脸分析数据，返回 AI 评价。

**请求体：**
```json
{
  "face_analysis": {
    "has_face": true,
    "num_faces": 1,
    "blendshapes_top": [
      { "name": "eyeBlinkLeft", "score": 0.8 }
    ],
    "landmark_stats": {
      "mouth_open": 0.3,
      "eye_blink_left": 0.8,
      "eye_blink_right": 0.2,
      "eyebrow_raise": 0.1,
      "head_pose_yaw": 5.0,
      "head_pose_pitch": -2.0,
      "head_pose_roll": 1.0
    },
    "timestamp_ms": 1234567890
  },
  "image_base64": null
}
```

**响应：**
```json
{
  "message": "You're looking great with that smile!",
  "error": null
}
```

### GET /health

健康检查端点，返回服务状态。

**响应：**
```json
{
  "ok": true,
  "hasApiKey": true
}
```

## 开发与测试

### 模拟器测试

iOS 模拟器可以直接使用 `http://localhost:8080` 连接本地后端。

### 真机测试

真机需要连接到电脑的 IP 地址。请参考项目根目录的 `SETUP_AND_RELEASE.md` 了解如何配置。

## 部署到生产环境

关于如何部署到生产环境（如 Railway、Vercel、自建服务器等），请参考项目根目录的 `SETUP_AND_RELEASE.md`。

## 环境变量说明

- `PORT`: 服务器端口（默认：8080）
- `OPENAI_API_KEY`: OpenAI API Key（必需）
- `OPENAI_MODEL`: OpenAI 模型名称（可选，默认：gpt-4o-mini）

## 注意事项

- 确保 `.env` 文件在 `.gitignore` 中，不要提交 API Key
- 生产环境请使用 HTTPS
- 生产环境建议限制 CORS 来源，而不是允许所有来源（`*`）

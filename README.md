# Face Mesh AI Bubble Demo

一个使用 ARKit + MediaPipe Face Landmarker + AI API 的 iOS Demo App，在 AR 摄像画面上叠加 AI 助手气泡。

## 功能特性

- ✅ ARKit 实时相机帧获取（支持 Face Tracking 和 World Tracking）
- ✅ MediaPipe Face Landmarker 人脸关键点/表情分析
- ✅ 结构化数据摘要提取（landmarks、blendshapes、头部姿态）
- ✅ AI API 集成（支持直接调用和后端代理模式）
- ✅ SwiftUI 气泡 UI（自动消失/手动关闭）
- ✅ 帧节流控制（10-15fps，避免性能问题）
- ✅ 调试面板（FPS、节流设置、手动触发）

## 技术栈

- **UI**: SwiftUI
- **AR**: ARKit + RealityKit (ARView)
- **ML**: MediaPipe Tasks Vision (Face Landmarker)
- **并发**: Swift Concurrency (async/await)
- **依赖管理**: CocoaPods

## 项目结构

```
Bestie-Check/
├── App/
│   └── Bestie_CheckApp.swift          # App 入口
├── UI/
│   ├── ContentView.swift              # 主界面
│   ├── ARViewContainer.swift          # ARView SwiftUI 包装
│   ├── BubbleView.swift               # AI 气泡视图
│   └── DebugPanelView.swift           # 调试面板
├── ViewModel/
│   └── FaceMeshAssistantViewModel.swift  # 状态管理与业务逻辑
├── Services/
│   ├── Models.swift                   # 数据模型（FaceAnalysisSummary 等）
│   ├── ARFrameProvider.swift          # ARKit 取帧层
│   ├── FaceLandmarkerService.swift    # MediaPipe 推理层
│   └── AIClient.swift                 # AI API 封装层
└── Resources/
    └── face_landmarker.task           # MediaPipe 模型文件（需下载）
```

## 安装步骤

### 1. 安装 CocoaPods（如果未安装）

```bash
sudo gem install cocoapods
```

### 2. 安装依赖

```bash
cd /Users/mike/Desktop/Bestie-Check
pod install
```

### 3. 下载 MediaPipe Face Landmarker 模型

1. 访问 [MediaPipe Face Landmarker Model](https://developers.google.com/mediapipe/solutions/vision/face_landmarker)
2. 下载 `face_landmarker.task` 文件
3. 将文件添加到 Xcode 项目：
   - 在 Xcode 中右键点击 `Bestie-Check` 文件夹
   - 选择 "Add Files to Bestie-Check..."
   - 选择下载的 `face_landmarker.task` 文件
   - **重要**：确保在 "Add to targets" 中勾选 `Bestie-Check`
   - 确保文件出现在项目的 Bundle 中（Build Phases > Copy Bundle Resources）

### 4. 打开项目

**重要**：使用 `.xcworkspace` 而不是 `.xcodeproj`

```bash
open Bestie-Check.xcworkspace
```

### 5. 配置 Info.plist

在 `Info.plist` 中添加相机权限：

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access for AR face tracking and analysis.</string>
```

如果使用后置摄像头降级模式，还需要：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app may need microphone access for AR features.</string>
```

## 配置 AI API

### 方式 1：直接调用（仅 Demo，不安全）

编辑 `Services/AIClient.swift`：

```swift
static let `default` = Config(
    endpoint: "https://api.openai.com/v1/chat/completions",  // 替换为你的 endpoint
    apiKey: "sk-your-api-key-here",  // ⚠️ 不安全：仅用于 Demo
    headers: [
        "Content-Type": "application/json"
    ],
    timeout: 10.0,
    maxRetries: 2
)
```

**注意**：这种方式会将 API Key 暴露在客户端代码中，仅用于开发测试。

### 方式 2：后端代理模式（推荐）

1. 实现后端 API（例如 Node.js/Python），接收 `FaceAnalysisSummary` JSON
2. 在后端调用真实的 AI API（OpenAI、Claude 等）
3. 编辑 `Services/AIClient.swift`：

```swift
init(config: Config = .backendProxy) {  // 使用 backendProxy
    // ...
}
```

后端接口约定：

**请求**：
```json
POST /api/face-analysis
Content-Type: application/json

{
  "faceAnalysis": {
    "hasFace": true,
    "numFaces": 1,
    "blendshapesTop": [
      {"name": "smile", "score": 0.82},
      {"name": "eyeBlinkLeft", "score": 0.12}
    ],
    "landmarkStats": {
      "mouthOpen": 0.23,
      "eyeBlinkLeft": 0.12,
      "eyeBlinkRight": 0.08,
      "eyebrowRaise": 0.05
    },
    "timestampMs": 123456789
  },
  "imageBase64": "..."  // 可选，如果启用上传整图
}
```

**响应**：
```json
{
  "message": "I can see you're smiling! 😊",
  "error": null
}
```

## 运行

1. 在 Xcode 中选择真机设备（ARKit 需要真机，不支持模拟器）
2. 点击运行（⌘R）
3. 授权相机权限
4. 将脸对准前置摄像头
5. 等待 AI 分析并显示气泡回复

## 调试功能

右上角调试面板提供：

- **Throttle Interval**: 调整帧处理间隔（默认 200ms ≈ 5fps）
- **Upload Full Image**: 切换是否上传整张图片（默认关闭，仅上传结构化数据）
- **Show 'No Face' Message**: 是否显示"未检测到人脸"提示
- **Manual Analysis**: 手动触发一次分析

## 性能优化

- **帧节流**: 默认每 200ms 处理一帧（≈5fps），可在调试面板调整
- **只保留最新帧**: 使用 `AsyncStream` 自动丢弃旧帧
- **后台推理**: MediaPipe 推理在后台队列执行，不阻塞 UI
- **异步网络**: AI API 调用使用 async/await，不阻塞主线程

## 设备要求

- iOS 15.0+
- 支持 ARKit 的真机设备（iPhone/iPad）
- **推荐**: 支持 TrueDepth 的设备（iPhone X 及更新），可使用 `ARFaceTrackingConfiguration`
- **降级支持**: 不支持 TrueDepth 的设备可使用 `ARWorldTrackingConfiguration` + 前置摄像头

## 常见问题

### 1. MediaPipe 模型文件找不到

确保 `face_landmarker.task` 已添加到项目 Bundle 中：
- 检查 Build Phases > Copy Bundle Resources
- 在代码中添加断点，打印 `Bundle.main.path(forResource: "face_landmarker", ofType: "task")`

### 2. CocoaPods 安装失败

```bash
pod deintegrate
pod install --repo-update
```

### 3. SwiftUI Preview 报错

MediaPipe 依赖可能影响 Preview。解决方案：
- 使用条件编译在 Preview 中禁用 AR 初始化
- 或直接运行在真机上测试

### 4. ARSession 无法启动

- 确保在真机上运行（模拟器不支持 ARKit）
- 检查 Info.plist 中的相机权限
- 检查设备是否支持 ARKit

### 5. AI API 调用失败

- 检查网络连接
- 验证 API endpoint 和 key 配置
- 查看控制台错误日志
- 如果使用后端代理，确保后端服务正常运行

## 代码说明

### 关键模块

1. **ARFrameProvider**: 从 ARSession 获取 `CVPixelBuffer`，通过 `AsyncStream` 输出
2. **FaceLandmarkerService**: 初始化 MediaPipe Face Landmarker，处理帧并提取摘要
3. **AIClient**: 封装 AI API 调用，支持重试和错误处理
4. **FaceMeshAssistantViewModel**: 协调各模块，管理状态和 UI 更新

### 数据流

```
ARFrame (CVPixelBuffer)
  ↓
ARFrameProvider.frameStream
  ↓ (节流)
FaceLandmarkerService.processFrame
  ↓
FaceAnalysisSummary (结构化数据)
  ↓
AIClient.getAIReply
  ↓
BubbleView (SwiftUI)
```

## 许可证

本项目为 Demo 用途，请根据实际需求调整和优化。

## 后续优化建议

- [ ] 实现流式 SSE 响应（边生成边更新气泡）
- [ ] 添加更多 landmark 派生特征（例如情绪识别）
- [ ] 优化 MediaPipe 推理性能（使用 GPU delegate）
- [ ] 添加历史对话记录
- [ ] 支持多语言 AI 回复
- [ ] 添加截图/录制功能

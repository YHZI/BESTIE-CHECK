# 安装与配置指南

## 快速开始

### 1. 安装 CocoaPods

```bash
sudo gem install cocoapods
```

### 2. 安装依赖

```bash
cd /Users/mike/Desktop/Bestie-Check
pod install
```

### 3. 下载 MediaPipe Face Landmarker 模型

#### 3.1 下载模型文件

1. 访问：https://developers.google.com/mediapipe/solutions/vision/face_landmarker
2. 下载 `face_landmarker.task` 文件（选择最新版本）

#### 3.2 添加到 Xcode 项目

**方法 A：通过菜单添加（推荐）**

1. 在 Xcode 项目导航器中，**右键点击 `Bestie-Check` 文件夹**（或 `Resources` 文件夹）
2. 选择 **"Add Files to 'Bestie-Check'..."**
3. 在文件选择对话框中：
   - 找到并选择下载的 `face_landmarker.task` 文件
   - ✅ **必须勾选**："Copy items if needed"（将文件复制到项目目录）
   - ✅ **必须勾选**："Add to targets: Bestie-Check"（添加到构建目标）
   - 点击 **"Add"**

**方法 B：直接拖拽**

1. 在 Finder 中找到 `face_landmarker.task` 文件
2. **拖拽**到 Xcode 项目导航器的 `Bestie-Check` 或 `Resources` 文件夹
3. 在弹出的对话框中：
   - ✅ 勾选 "Copy items if needed"
   - ✅ 勾选 "Add to targets: Bestie-Check"
   - 点击 "Finish"

#### 3.3 验证文件已正确添加

1. **检查项目导航器**：
   - 应该能看到 `face_landmarker.task` 文件
   - 文件图标应该是正常的（不是红色的）

2. **检查 Build Phases**：
   - 选择项目 Target：`Bestie-Check`
   - 打开 **"Build Phases"** 标签页
   - 展开 **"Copy Bundle Resources"**
   - ✅ 确认 `face_landmarker.task` 在列表中
   - 如果不在，点击 **"+"** 按钮手动添加

3. **验证代码**：
   - 运行项目，查看控制台输出
   - 如果看到 "✅ FaceLandmarker initialized"，说明模型加载成功
   - 如果看到 "❌ face_landmarker.task not found"，说明文件未正确添加

**详细说明请参考**：`Bestie-Check/Resources/README_MODEL.md`

### 4. 配置相机权限

本项目使用 **Xcode 自动生成 Info.plist**（`GENERATE_INFOPLIST_FILE = YES`），权限文案通过工程的 `INFOPLIST_KEY_...` 写入。

如果你想手动在 Xcode UI 中确认：
1. 选择 Target：`Bestie-Check`
2. 打开 **Info** 标签页
3. 确认存在：
   - `Privacy - Camera Usage Description`
   - `Privacy - Microphone Usage Description`

**方式 B：在 Xcode 项目设置中配置**

1. 选择项目 Target > Info
2. 添加以下键值对：
   - `Privacy - Camera Usage Description`: "This app needs camera access for AR face tracking and analysis."
   - `Privacy - Microphone Usage Description`: "This app may need microphone access for AR features."

### 5. 打开项目

**重要**：必须使用 `.xcworkspace`，不要使用 `.xcodeproj`

```bash
open Bestie-Check.xcworkspace
```

### 6. 配置 AI API（二选一）

#### 方式 1：直接调用（仅 Demo）

编辑 `Services/AIClient.swift`，修改 `Config.default`：

```swift
static let `default` = Config(
    endpoint: "https://api.openai.com/v1/chat/completions",
    apiKey: "sk-your-api-key-here",  // ⚠️ 不安全
    // ...
)
```

#### 方式 2：后端代理（推荐）

1. 实现后端 API（参考 README.md 中的接口约定）
2. 编辑 `Services/AIClient.swift`：

```swift
init(config: Config = .backendProxy) {  // 使用 backendProxy
    // ...
}
```

### 7. 运行

1. 连接真机设备（ARKit 不支持模拟器）
2. 选择目标设备
3. 点击运行（⌘R）
4. 授权相机权限
5. 将脸对准前置摄像头

## 验证安装

### 检查 MediaPipe 模型

在 `FaceLandmarkerService.swift` 的 `setupFaceLandmarker()` 方法中添加断点，检查：

```swift
guard let modelPath = Bundle.main.path(forResource: "face_landmarker", ofType: "task") else {
    print("❌ face_landmarker.task not found")
    return
}
print("✅ Model path: \(modelPath)")
```

### 检查 CocoaPods

确保 `Pods` 文件夹存在，且包含 `MediaPipeTasksVision`。

### 检查权限

运行后，系统应弹出相机权限请求。如果未弹出，检查 Info.plist 配置。

## 常见问题

### Pod install 失败

```bash
pod deintegrate
pod cache clean --all
pod install --repo-update
```

### 找不到 face_landmarker.task

- 确认文件已添加到项目
- 确认在 Build Phases > Copy Bundle Resources 中
- 尝试 Clean Build Folder (⌘⇧K) 后重新构建

### SwiftUI Preview 报错

MediaPipe 依赖可能影响 Preview。解决方案：
- 使用条件编译在 Preview 中禁用 AR 初始化
- 或直接在真机上测试

### ARSession 无法启动

- ✅ 确保在真机上运行（模拟器不支持）
- ✅ 检查相机权限
- ✅ 检查设备是否支持 ARKit（iPhone 6s 及以上）

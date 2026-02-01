# MediaPipe Face Landmarker 模型文件说明

## 📍 文件位置

`face_landmarker.task` 文件应该放在这个 `Resources/` 文件夹中。

## 📥 下载模型

1. 访问 MediaPipe 官方页面：
   https://developers.google.com/mediapipe/solutions/vision/face_landmarker

2. 下载 `face_landmarker.task` 文件（选择适合的版本，通常选择最新版本）

## ➕ 添加到 Xcode 项目

### 方法 1：通过 Xcode 界面添加（推荐）

1. **下载模型文件后**，在 Finder 中找到 `face_landmarker.task` 文件

2. **在 Xcode 中**：
   - 右键点击项目导航器中的 `Bestie-Check` 文件夹（或 `Resources` 文件夹）
   - 选择 **"Add Files to 'Bestie-Check'..."**

3. **在文件选择对话框中**：
   - 找到并选择 `face_landmarker.task` 文件
   - ✅ **重要**：勾选 **"Copy items if needed"**（这样文件会被复制到项目目录）
   - ✅ **重要**：在 **"Add to targets"** 中勾选 **"Bestie-Check"**
   - 点击 **"Add"**

4. **验证文件已添加**：
   - 在项目导航器中应该能看到 `face_landmarker.task` 文件
   - 文件应该显示在 `Resources` 文件夹下（或直接在 `Bestie-Check` 文件夹下）

5. **检查 Build Phases**：
   - 选择项目 Target：`Bestie-Check`
   - 打开 **"Build Phases"** 标签
   - 展开 **"Copy Bundle Resources"**
   - ✅ 确认 `face_landmarker.task` 在列表中
   - 如果不在，点击 **"+"** 按钮添加它

### 方法 2：直接拖拽

1. 在 Finder 中找到 `face_landmarker.task` 文件
2. 直接拖拽到 Xcode 项目导航器的 `Resources` 文件夹（或 `Bestie-Check` 文件夹）
3. 在弹出的对话框中：
   - ✅ 勾选 **"Copy items if needed"**
   - ✅ 勾选 **"Add to targets: Bestie-Check"**
   - 点击 **"Finish"**

## ✅ 验证安装

运行以下代码检查模型文件是否正确加载：

在 `FaceLandmarkerService.swift` 的 `setupFaceLandmarker()` 方法中，添加调试代码：

```swift
guard let modelPath = Bundle.main.path(forResource: "face_landmarker", ofType: "task") else {
    print("❌ face_landmarker.task not found in Bundle. Please download and add to project.")
    return
}
print("✅ Model found at: \(modelPath)")  // 添加这行来验证
```

如果控制台输出路径，说明文件已正确添加。

## 📁 最终项目结构应该是：

```
Bestie-Check/
├── Resources/
│   └── face_landmarker.task    ← 模型文件在这里
├── Services/
│   └── FaceLandmarkerService.swift
└── ...
```

## ⚠️ 常见问题

### 问题 1：运行时找不到文件

**原因**：文件没有添加到 "Copy Bundle Resources"

**解决**：
1. 选择 Target > Build Phases > Copy Bundle Resources
2. 点击 "+" 添加 `face_landmarker.task`
3. Clean Build Folder (⌘⇧K)
4. 重新构建

### 问题 2：文件在项目导航器中显示为红色

**原因**：文件路径引用错误

**解决**：
1. 删除红色引用
2. 重新添加文件（确保勾选 "Copy items if needed"）

### 问题 3：文件大小很大

**说明**：`face_landmarker.task` 文件通常有几 MB 到几十 MB，这是正常的。

# 快速开始指南

## 📍 face_landmarker.task 文件放置位置

### 简单回答

**将 `face_landmarker.task` 文件放在项目的 `Bestie-Check/Resources/` 文件夹中，并通过 Xcode 添加到项目。**

### 详细步骤

#### 步骤 1：下载模型文件

访问并下载：
https://developers.google.com/mediapipe/solutions/vision/face_landmarker

下载 `face_landmarker.task` 文件（通常几 MB 到几十 MB）

#### 步骤 2：在 Xcode 中添加文件

**方式 1：右键菜单添加**

1. 打开 Xcode 项目（`Bestie-Check.xcworkspace`）
2. 在左侧项目导航器中，找到 `Bestie-Check` 文件夹
3. **右键点击** `Bestie-Check` 文件夹
4. 选择 **"Add Files to 'Bestie-Check'..."**
5. 在文件选择对话框中：
   - 找到下载的 `face_landmarker.task` 文件
   - ✅ **勾选** "Copy items if needed"
   - ✅ **勾选** "Add to targets: Bestie-Check"
   - 点击 "Add"

**方式 2：直接拖拽**

1. 在 Finder 中找到 `face_landmarker.task` 文件
2. 直接**拖拽**到 Xcode 项目导航器的 `Bestie-Check` 文件夹中
3. 在弹出的对话框中：
   - ✅ 勾选 "Copy items if needed"
   - ✅ 勾选 "Add to targets: Bestie-Check"
   - 点击 "Finish"

#### 步骤 3：验证文件已添加

**检查 1：项目导航器**
- 在 Xcode 左侧应该能看到 `face_landmarker.task` 文件
- 文件图标应该是正常的（不是红色）

**检查 2：Build Phases**
1. 点击项目名称（最顶部）
2. 选择 Target：`Bestie-Check`
3. 打开 **"Build Phases"** 标签
4. 展开 **"Copy Bundle Resources"**
5. ✅ 确认 `face_landmarker.task` 在列表中

**检查 3：运行验证**
- 运行项目（⌘R）
- 查看控制台输出
- 如果看到 "✅ FaceLandmarker initialized"，说明成功
- 如果看到 "❌ face_landmarker.task not found"，说明文件未正确添加

### 📁 最终文件结构

```
Bestie-Check/
├── Resources/
│   └── face_landmarker.task    ← 模型文件在这里
├── Services/
│   └── FaceLandmarkerService.swift
└── ...
```

### ⚠️ 常见错误

**错误 1：文件显示为红色**
- **原因**：文件路径引用错误
- **解决**：删除红色引用，重新添加文件

**错误 2：运行时找不到文件**
- **原因**：文件没有添加到 "Copy Bundle Resources"
- **解决**：
  1. Target > Build Phases > Copy Bundle Resources
  2. 点击 "+" 添加 `face_landmarker.task`
  3. Clean Build Folder (⌘⇧K)
  4. 重新构建

**错误 3：文件太大**
- **说明**：这是正常的，模型文件通常有几 MB 到几十 MB

### 💡 提示

- 文件可以放在 `Bestie-Check` 根目录或 `Resources` 子文件夹中
- 重要的是确保文件被添加到 Target 和 Copy Bundle Resources
- 代码中使用 `Bundle.main.path(forResource: "face_landmarker", ofType: "task")` 来查找文件，所以文件名必须完全匹配

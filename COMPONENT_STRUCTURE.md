# ReactTextBar 组件结构图

## 组件层次结构

```
ContentView
    └── ZStack
        ├── ARViewContainer (AR相机)
        │
        ├── if viewModel.isBubbleVisible
        │   └── VStack
        │       ├── HStack (顶部对齐)
        │       │   ├── ReactTextBar ← 我们创建的组件
        │       │   │   └── Text
        │       │   │       └── .background(BubbleWithLCutout)
        │       │   │
        │       │   └── Button (关闭按钮 X)
        │       │       └── Image(systemName: "xmark.circle.fill")
        │       │
        │       └── Spacer()
        │
        ├── DebugPanelView (右上角调试面板)
        ├── Loading指示器
        ├── 错误提示
        └── 测试按钮 (底部)
```

## ReactTextBar 组件详情

```
ReactTextBar 组件
├── 输入参数
│   ├── text: String (必需)
│   ├── backgroundColor: Color (可选，默认 systemGray5)
│   └── textColor: Color (可选，默认 primary)
│
└── 视图结构
    └── Text(text)
        ├── .font(.system(size: 16))
        ├── .foregroundColor(textColor)
        ├── .padding(.horizontal, 16)
        ├── .padding(.vertical, 12)
        └── .background(BubbleWithLCutout)
            └── .fill(backgroundColor)
```

## BubbleWithLCutout Shape

```
L形缺口气泡框 (从左上角开始顺时针绘制)

    cornerRadius
    ┌─→ ●──────────────┐
    │                  │  ← cutoutHeight (rect.height / 2)
    │                  ├──┐
    │                  │  │
    │                  │  │
    │   文本内容区域    │  │
    │                  │  │
    │                  │  │
    ●──────────────────●  │
    └─→ cornerRadius      │
    
    └───────────────────┘
        cutoutWidth
        (rect.width / 2)

关键点：
● = 圆角 (cornerRadius = 18pt)
┐┌ = L形缺口的直角
```

## 绘制路径顺序

```swift
1. 起点：左上角圆角后
   ↓
2. 向右：到缺口开始位置
   ↓
3. 向下：缺口垂直边 (cutoutHeight)
   ↓
4. 向右：缺口水平边 (cutoutWidth)
   ↓
5. 向下：到右下角
   ↓
6. 右下圆角
   ↓
7. 向左：底边
   ↓
8. 左下圆角
   ↓
9. 向上：左边
   ↓
10. 左上圆角
    ↓
11. 闭合路径
```

## 数据流

```
用户操作 / AR检测
    ↓
FaceMeshAssistantViewModel
    ├── triggerTestBubble() ← 测试按钮触发
    ├── updateBubble() ← AR处理触发
    │   ├── bubbleText = "..."
    │   └── isBubbleVisible = true
    ↓
ContentView 监听变化
    ↓
if isBubbleVisible == true
    ↓
显示 ReactTextBar(text: bubbleText)
    ↓
用户点击 X 按钮
    ↓
viewModel.hideBubble()
    ↓
isBubbleVisible = false
    ↓
气泡消失（带动画）
```

## 文件依赖关系

```
Bestie_CheckApp.swift (App入口)
    └── ContentView.swift
        ├── 依赖 → FaceMeshAssistantViewModel.swift
        │           ├── 发布 bubbleText
        │           ├── 发布 isBubbleVisible
        │           └── 方法 hideBubble()
        │           └── 方法 triggerTestBubble()
        │
        ├── 依赖 → ReactTextBar (compoent.swift)
        │           └── 依赖 → BubbleWithLCutout
        │
        ├── 依赖 → ARViewContainer.swift
        ├── 依赖 → DebugPanelView.swift
        └── 使用系统组件
            ├── Button
            ├── Image
            ├── Text
            └── ProgressView
```

## 布局尺寸

```
┌───────────────────────────────────┐
│ iPhone 屏幕 (例: 393 x 852)        │
│                                   │
│  ┌─── ReactTextBar ────┐          │
│  │ padding: 16, 12     │        ┌┐│ ← 缺口 + X按钮
│  │ font: 16pt          │        └┘│   位置: offset(x: -8)
│  │ 气泡自适应宽度       │          │
│  └─────────────────────┘          │
│  ↑ .padding(.top, 60)             │
│  ↑ .padding(.horizontal, 16)      │
│                                   │
│         AR Camera View            │
│                                   │
│                                   │
│  ┌─────────────────┐              │
│  │  Test Bubble   │ ← 测试按钮    │
│  └─────────────────┘              │
│  ↑ .padding(.bottom, 50)          │
└───────────────────────────────────┘
```

## 动画时序

```
气泡出现:
  0ms ─────────────→ 300ms
  [隐藏]  →  [出现动画]  →  [完全显示]
         spring(response: 0.3, dampingFraction: 0.7)

气泡消失:
  触发 hideBubble()
  ↓
  立即执行 (取消自动隐藏任务)
  ↓
  isBubbleVisible = false
  ↓
  动画过渡 (300ms)
  ↓
  完全隐藏

自动隐藏:
  显示气泡
  ↓
  等待 3-5秒 (随机)
  ↓
  自动执行 hideBubble()
```

## 测试路径

```
方式1: 手动测试按钮
  点击 "Test Bubble"
  ↓
  viewModel.triggerTestBubble()
  ↓
  updateBubble(text: "Sorry!...", autoHide: false)
  ↓
  气泡显示 (不自动隐藏)

方式2: AR自动触发
  AR相机运行
  ↓
  检测不到人脸
  ↓
  updateBubble(text: "No face detected", autoHide: true)
  ↓
  气泡显示 (3-5秒后自动隐藏)

方式3: Preview预览
  打开 TestReactTextBar.swift
  ↓
  Xcode Canvas 显示
  ↓
  直接查看组件渲染
```

---
**说明:** 此图展示了 ReactTextBar 组件的完整结构和集成关系

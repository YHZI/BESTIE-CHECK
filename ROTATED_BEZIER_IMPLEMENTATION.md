# 旋转90度的Cubic Bezier曲线应用

## 实现时间
2026年2月6日

## 🎯 目标

使用 `cubic-bezier(0.00, 0.45, 0.00, 1.00)` 曲线，旋转90度后应用到缺口的拐弯处，创建从水平到垂直的平滑转折。

## 📐 曲线分析

### 原始曲线：cubic-bezier(0.00, 0.45, 0.00, 1.00)

**控制点：**
- 控制点1: (0%, 45%)
- 控制点2: (0%, 100%)

**特点：**
- 两个控制点的X坐标都是0%，在起点位置
- Y坐标分别是45%和100%
- 创造一个快速启动的曲线

### 旋转90度（顺时针）

当我们将曲线旋转90度用于从水平（上边线）到垂直（下边线）的转折时：

**坐标转换：**
- X ↔ Y 互换
- 调整方向以适应新的坐标系

**旋转后的控制点：**
- 原始 (0%, 45%) → 旋转 → (45%, 0%)
- 原始 (0%, 100%) → 旋转 → (100%, 0%)

## ✅ Swift 实现

### 第一段：拐弯曲线（上→下）

```swift
let bendStart = CGPoint(x: rect.maxX - cutoutWidth, y: rect.minY)
let bendEnd = CGPoint(x: rect.maxX - cutoutWidth, y: rect.minY + cutoutHeight)

// 控制点1: (45%, 0%)
let control1 = CGPoint(
    x: bendStart.x + cutoutWidth * 0.45,     // 向右偏移45%
    y: bendStart.y + cutoutHeight * 0.0      // y: 0%，保持在顶部
)

// 控制点2: (100%, 0%)
let control2 = CGPoint(
    x: bendStart.x + cutoutWidth * 1.0,      // 向右偏移100%
    y: bendStart.y + cutoutHeight * 0.0      // y: 0%，保持在顶部
)

path.addCurve(to: bendEnd, control1: control1, control2: control2)
```

### 第二段：返回曲线（下→右）

```swift
let returnEnd = CGPoint(x: rect.maxX, y: rect.minY + cutoutHeight)

// 对称的控制点创建平滑过渡
let returnControl1 = CGPoint(
    x: rect.maxX - cutoutWidth,              // 起点位置
    y: rect.minY + cutoutHeight
)
let returnControl2 = CGPoint(
    x: rect.maxX - cutoutWidth * 0.45,       // 中间位置
    y: rect.minY + cutoutHeight
)

path.addCurve(to: returnEnd, control1: returnControl1, control2: returnControl2)
```

## 🎨 视觉效果

### 拐弯曲线的作用

```
上边线 ────●  起点 (cutoutLeft, top)
           │
           │  ← 控制点1 (45%, 0%) 
           │     轻微向右拉，快速启动
           │
           │  ← 控制点2 (100%, 0%)
           │     强力向右拉，平滑过渡
           │
           ●  终点 (cutoutLeft, cutoutBottom)
           垂直边
```

### 完整路径效果

```
上边线 ──────────●  拐弯起点
                 │
                 │  ← 第一段：向下的曲线
                 │     两个控制点都向右拉
                 │
                 ●──────●  拐弯终点/返回起点
                         ← 第二段：向右的曲线
                            两个控制点沿水平方向
                         ●  返回终点
                         │
                       右边线
```

## 📊 关键参数

### 第一段曲线（拐弯）
| 参数 | 值 | 说明 |
|------|-----|------|
| 起点X | rect.maxX - 84 | 缺口左边界 |
| 起点Y | rect.minY | 气泡顶部 |
| 终点X | rect.maxX - 84 | 保持X不变 |
| 终点Y | rect.minY + 40 | 向下40pt |
| 控制点1 X | 起点X + 84×0.45 = 起点X + 37.8 | 向右45% |
| 控制点1 Y | rect.minY | 保持顶部 |
| 控制点2 X | 起点X + 84×1.0 = rect.maxX | 到达右边界 |
| 控制点2 Y | rect.minY | 保持顶部 |

### 第二段曲线（返回）
| 参数 | 值 | 说明 |
|------|-----|------|
| 起点X | rect.maxX - 84 | 缺口左边界 |
| 起点Y | rect.minY + 40 | 缺口底部 |
| 终点X | rect.maxX | 右边界 |
| 终点Y | rect.minY + 40 | 保持Y不变 |
| 控制点1 X | rect.maxX - 84 | 起点位置 |
| 控制点1 Y | rect.minY + 40 | 保持底部 |
| 控制点2 X | rect.maxX - 37.8 | 中间位置 |
| 控制点2 Y | rect.minY + 40 | 保持底部 |

## 💡 为什么这样旋转？

### 原始曲线的特点
`cubic-bezier(0.00, 0.45, 0.00, 1.00)` 是一个**快速启动**的曲线：
- 开始时快速变化
- 然后逐渐平缓
- 适合创建自然的转折

### 旋转后的效果
当旋转90度应用到拐弯处时：
- 保持了快速启动的特性
- 在拐弯处创造自然的弧度
- 避免生硬的直角转折

## 🔍 坐标转换详解

### 旋转90度的数学原理

原始点 (x, y) 旋转90度（顺时针）后变为 (y, -x)

但在我们的应用中，需要适应新的坐标系：

**原始曲线（水平方向0→1）：**
- 控制点1: (0, 0.45) - 在起点，向上45%
- 控制点2: (0, 1.0) - 在起点，到达终点Y

**旋转到垂直方向：**
- 需要从起点向下走
- 控制点应该向右拉，不是向上

**最终映射：**
- (0, 0.45) → (0.45, 0) - X和Y互换
- (0, 1.0) → (1.0, 0) - X和Y互换

## 🎯 视觉对比

### 不使用曲线（直角）
```
────●
    │
    │  生硬的直角
    │
    ●───
```

### 使用旋转后的曲线
```
────●
     ╲
      ╲  平滑的弧度
       │
       ●──
```

## ✅ 优势

1. **自然的转折**
   - 利用cubic-bezier的特性
   - 快速启动，平滑过渡

2. **精确控制**
   - 使用设计工具的曲线参数
   - 可预测的视觉效果

3. **易于调整**
   - 修改百分比即可
   - 保持曲线特性不变

## 🔧 如何微调

### 调整拐弯的紧凑度
```swift
// 更紧凑（减小45%）
let control1 = CGPoint(
    x: bendStart.x + cutoutWidth * 0.3,  // 改为30%
    y: bendStart.y + cutoutHeight * 0.0
)
```

### 调整拐弯的平滑度
```swift
// 更平滑（控制点2向下移动）
let control2 = CGPoint(
    x: bendStart.x + cutoutWidth * 1.0,
    y: bendStart.y + cutoutHeight * 0.1   // 向下10%
)
```

---
**实现方式：** 旋转90度的cubic-bezier曲线  
**原始曲线：** cubic-bezier(0.00, 0.45, 0.00, 1.00)  
**应用位置：** 缺口拐弯处  
**完成时间：** 2026-02-06  
**状态：** ✅ 完成

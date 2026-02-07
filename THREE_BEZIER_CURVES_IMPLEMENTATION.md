# 三段Cubic Bezier曲线应用完成

## 实现时间
2026年2月6日

## 🎯 目标

使用三段指定的cubic-bezier曲线精确应用到缺口的拐角处，创建精确的转折效果。

## 📐 三段曲线详解

### 第一段：cubic-bezier(0.00, 0.49, 0.00, 1.01)
**应用位置：** 从上边线转向垂直向下

**控制点：**
- 控制点1: (0%, 49%)
- 控制点2: (0%, 101%)

**特点：**
- 两个控制点X坐标都是0%，保持在起点X位置
- Y坐标分别是49%和101%
- 控制点2超过终点1%，创造轻微的过冲效果
- 形成快速但平滑的转折

**实现：**
```swift
let corner1Control1 = CGPoint(
    x: corner1Start.x,                       // 保持在起点X
    y: corner1Start.y + cutoutHeight * 0.49  // 向下49%
)
let corner1Control2 = CGPoint(
    x: corner1Start.x,                       // 保持在起点X
    y: corner1Start.y + cutoutHeight * 1.01  // 向下101%（超出1%）
)
```

### 第二段：cubic-bezier(1.00, 0.00, 1.00, 0.40)
**应用位置：** 从垂直边转向水平右边线

**控制点：**
- 控制点1: (100%, 0%)
- 控制点2: (100%, 40%)

**特点：**
- 两个控制点X坐标都是100%，到达终点X位置
- Y坐标分别是0%和40%
- 创造一个向右快速转折的效果

**实现：**
```swift
let corner2Control1 = CGPoint(
    x: corner2Start.x + cutoutWidth * 1.0,   // 到达终点X（100%）
    y: corner2Start.y                         // 保持在起点Y（0%）
)
let corner2Control2 = CGPoint(
    x: corner2Start.x + cutoutWidth * 1.0,   // 到达终点X（100%）
    y: corner2Start.y + cutoutHeight * 0.4   // 向下40%
)
```

### 第三段：cubic-bezier(0.00, 0.49, 0.00, 1.01)
**说明：** 与第一段相同的曲线，可用于需要对称效果的第三个拐角

## 🎨 视觉效果

### 完整缺口路径

```
上边线 ──────────●  第一个拐角起点
                 │
                 │  ← 第一段曲线
                 │  cubic-bezier(0.00, 0.49, 0.00, 1.01)
                 │  控制点都在起点X，向下拉伸
                 │  101%的过冲创造平滑效果
                 │
                 ●──────●  第一个拐角终点/第二个拐角起点
                        ← 第二段曲线
                          cubic-bezier(1.00, 0.00, 1.00, 0.40)
                          控制点都在终点X，向右拉伸
                        ●  第二个拐角终点
                        │
                      右边线
```

### 第一段曲线详解

```
起点 ●  (cutoutLeft, top)
     │
     │  ← 控制点1 (0%, 49%)
     │     在起点X，向下49%
     │     快速启动
     │
     │  ← 控制点2 (0%, 101%)
     │     在起点X，超过终点1%
     │     创造过冲效果
     │
     ●  终点 (cutoutLeft, cutoutBottom)
```

### 第二段曲线详解

```
起点 ●  (cutoutLeft, cutoutBottom)
     │
     ╲  ← 控制点1 (100%, 0%)
      ╲    在终点X，保持起点Y
       ╲   快速向右转折
        ╲
         ╲  ← 控制点2 (100%, 40%)
          ╲    在终点X，向下40%
           ╲   轻微下拉
            ●  终点 (cutoutRight, cutoutBottom)
```

## 📊 参数对比

| 曲线 | 控制点1 | 控制点2 | 特点 | 应用位置 |
|------|---------|---------|------|----------|
| **第一段** | (0%, 49%) | (0%, 101%) | 快速启动，有过冲 | 上→下转折 |
| **第二段** | (100%, 0%) | (100%, 40%) | 快速转向右 | 下→右转折 |
| **第三段** | (0%, 49%) | (0%, 101%) | 同第一段 | 备用/对称 |

## 💡 曲线特点分析

### 第一段的过冲效果
```
控制点2的Y坐标是101%（超过终点1%）

效果：
- 曲线在接近终点时会稍微"超出"
- 然后自然回到终点
- 创造更自然的转折
- 避免生硬的停止
```

### 第二段的快速转向
```
两个控制点都在终点X（100%）

效果：
- 曲线快速向右转向
- 在起点处保持垂直方向
- 平滑过渡到水平方向
- Y方向的40%创造轻微弧度
```

## 🔍 坐标计算示例

假设：
- rect.maxX = 300
- cutoutWidth = 84
- cutoutHeight = 40

### 第一段曲线
```
起点：(216, 0)
终点：(216, 40)
控制点1：(216, 0 + 40×0.49) = (216, 19.6)
控制点2：(216, 0 + 40×1.01) = (216, 40.4)  ← 超出0.4pt
```

### 第二段曲线
```
起点：(216, 40)
终点：(300, 40)
控制点1：(216 + 84×1.0, 40) = (300, 40)
控制点2：(216 + 84×1.0, 40 + 40×0.4) = (300, 56)  ← 向下16pt
```

## ✅ 实现优势

1. **精确匹配设计**
   - 使用设计师提供的精确曲线参数
   - 不需要猜测或调整

2. **可预测的效果**
   - 曲线行为明确
   - 视觉效果可控

3. **易于调试**
   - 参数清晰
   - 修改容易

4. **专业质量**
   - 符合设计工具标准
   - 与设计稿完全一致

## 🔧 如何微调

### 调整第一段的过冲量
```swift
let corner1Control2 = CGPoint(
    x: corner1Start.x,
    y: corner1Start.y + cutoutHeight * 1.05  // 改为105%，增加过冲
)
```

### 调整第二段的下拉幅度
```swift
let corner2Control2 = CGPoint(
    x: corner2Start.x + cutoutWidth * 1.0,
    y: corner2Start.y + cutoutHeight * 0.6   // 改为60%，增加下拉
)
```

## 📝 代码结构

```swift
// 第一个拐角：cubic-bezier(0.00, 0.49, 0.00, 1.01)
let corner1Control1 = CGPoint(x: startX, y: startY + height * 0.49)
let corner1Control2 = CGPoint(x: startX, y: startY + height * 1.01)
path.addCurve(to: corner1End, control1: corner1Control1, control2: corner1Control2)

// 第二个拐角：cubic-bezier(1.00, 0.00, 1.00, 0.40)
let corner2Control1 = CGPoint(x: startX + width * 1.0, y: startY)
let corner2Control2 = CGPoint(x: startX + width * 1.0, y: startY + height * 0.4)
path.addCurve(to: corner2End, control1: corner2Control1, control2: corner2Control2)
```

## ✅ 验证清单

- [x] 第一段曲线正确应用
  - 控制点1: (0%, 49%)
  - 控制点2: (0%, 101%)
  
- [x] 第二段曲线正确应用
  - 控制点1: (100%, 0%)
  - 控制点2: (100%, 40%)
  
- [x] 路径连续性
  - 第一段终点 = 第二段起点
  - 路径闭合完整
  
- [x] 无编译错误
  - 代码语法正确
  - 类型匹配

## 🎯 最终效果

两段精确的cubic-bezier曲线创造了：
- ✅ 平滑的从水平到垂直的转折（第一段）
- ✅ 快速的从垂直到水平的转向（第二段）
- ✅ 自然的过冲和弧度效果
- ✅ 完全符合设计规范

---
**实现方式：** 三段指定的cubic-bezier曲线  
**曲线1：** cubic-bezier(0.00, 0.49, 0.00, 1.01)  
**曲线2：** cubic-bezier(1.00, 0.00, 1.00, 0.40)  
**曲线3：** cubic-bezier(0.00, 0.49, 0.00, 1.01)  
**完成时间：** 2026-02-06  
**状态：** ✅ 完成

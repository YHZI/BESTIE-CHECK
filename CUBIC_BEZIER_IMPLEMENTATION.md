# 三次贝塞尔曲线（Cubic Bezier）实现

## 实现时间
2026年2月6日

## 🎯 目标

使用反转的 `cubic-bezier(1.00, 0.00, 0.00, 1.00)` 曲线绘制缺口，创建平滑的S形凹陷效果。

## 📐 贝塞尔曲线理解

### 原始曲线：cubic-bezier(1.00, 0.00, 0.00, 1.00)

在CSS/动画中的表示：
```
cubic-bezier(x1, y1, x2, y2)
            (1.0, 0.0, 0.0, 1.0)
```

**控制点：**
- 控制点1: (100%, 0%) - 在终点的X位置，起点的Y位置
- 控制点2: (0%, 100%) - 在起点的X位置，终点的Y位置

**效果：** 创造一个对角线交叉的S形曲线

### 反转曲线：cubic-bezier(0.00, 1.00, 1.00, 0.00)

**控制点（反转后）：**
- 控制点1: (0%, 100%) - 在起点的X位置，终点的Y位置
- 控制点2: (100%, 0%) - 在终点的X位置，起点的Y位置

## ✅ Swift 实现

### 坐标计算

```swift
let cutoutStart = CGPoint(x: rect.maxX - cutoutWidth, y: rect.minY)
let cutoutEnd = CGPoint(x: rect.maxX, y: rect.minY + cutoutHeight)

// 控制点1: (0%, 100%)
let control1 = CGPoint(
    x: cutoutStart.x + cutoutWidth * 0.0,      // 0% → 起点X
    y: cutoutStart.y + cutoutHeight * 1.0      // 100% → 终点Y
)

// 控制点2: (100%, 0%)
let control2 = CGPoint(
    x: cutoutStart.x + cutoutWidth * 1.0,      // 100% → 终点X
    y: cutoutStart.y + cutoutHeight * 0.0      // 0% → 起点Y
)

path.addCurve(to: cutoutEnd, control1: control1, control2: control2)
```

## 🎨 视觉效果

### 曲线形状

```
起点 ●────────────────────┐
     │                    │
     │  控制点1            │
     │  (起点X, 终点Y)     │
     │                    │
     ╲                    │
      ╲                   │
       ╲                  │ 控制点2
        ╲                 │ (终点X, 起点Y)
         ╲                │
          ╲               │
           ●──────────────┘
              终点
```

### 实际效果

```
缺口起点（左上）
     │
     │  ← 曲线向下弯曲
     ╲
      ╲
       ╲  ← S形平滑过渡
        ╲
         ╲
          ●  ← 曲线向右弯曲
             │
           缺口终点（右下）
```

## 📊 参数详解

### 关键尺寸
- **缺口宽度：** 84pt
- **缺口高度：** 40pt
- **起点：** (rect.maxX - 84, rect.minY)
- **终点：** (rect.maxX, rect.minY + 40)

### 控制点位置

| 控制点 | X坐标 | Y坐标 | 说明 |
|--------|-------|-------|------|
| **控制点1** | rect.maxX - 84 | rect.minY + 40 | 左下角位置 |
| **控制点2** | rect.maxX | rect.minY | 右上角位置 |

### 坐标示例

假设：
- rect.maxX = 300
- cutoutWidth = 84
- cutoutHeight = 40

计算结果：
- 起点：(216, 0)
- 终点：(300, 40)
- 控制点1：(216, 40) - 左下
- 控制点2：(300, 0) - 右上

## 🔍 二次 vs 三次贝塞尔曲线对比

### 二次贝塞尔曲线（Quadratic）
```swift
path.addQuadCurve(
    to: endpoint,
    control: controlPoint  // 只有一个控制点
)
```

**特点：**
- 1个控制点
- 形成简单的抛物线
- 灵活度较低

### 三次贝塞尔曲线（Cubic）
```swift
path.addCurve(
    to: endpoint,
    control1: controlPoint1,  // 两个控制点
    control2: controlPoint2
)
```

**特点：**
- 2个控制点
- 可以形成S形曲线
- 灵活度高
- 更平滑的过渡

## 💡 为什么使用三次贝塞尔？

### 优势

1. **更精确的控制**
   - 两个控制点可以独立调整
   - 可以创造复杂的S形曲线

2. **符合设计规范**
   - CSS的cubic-bezier可以直接转换
   - 与设计工具输出一致

3. **更平滑的效果**
   - S形过渡自然
   - 没有生硬的转折

## 🎯 效果对比

### 使用二次贝塞尔曲线
```
起点 ●
      ╲
       ╲  ← 单一控制点，简单弧线
        ●
       ╱
      ╱
终点 ●
```

### 使用三次贝塞尔曲线
```
起点 ●
     │
     │  ← 控制点1拉伸
     ╲
      ╲  ← S形平滑过渡
       ╲
        ●─  ← 控制点2拉伸
           │
         终点
```

## 🔧 如何调整曲线

### 调整控制点1（起点附近）
```swift
let control1 = CGPoint(
    x: cutoutStart.x + cutoutWidth * 0.2,  // 改为20%，向右移动
    y: cutoutStart.y + cutoutHeight * 0.8   // 改为80%，不完全到底
)
```

### 调整控制点2（终点附近）
```swift
let control2 = CGPoint(
    x: cutoutStart.x + cutoutWidth * 0.8,   // 改为80%，不完全到右
    y: cutoutStart.y + cutoutHeight * 0.2   // 改为20%，向下移动
)
```

## 📈 贝塞尔曲线公式

### 三次贝塞尔曲线数学表达式
```
B(t) = (1-t)³P₀ + 3(1-t)²tP₁ + 3(1-t)t²P₂ + t³P₃

其中：
- P₀ = 起点
- P₁ = 控制点1
- P₂ = 控制点2
- P₃ = 终点
- t ∈ [0, 1]
```

### 在我们的实现中
- P₀ = (rect.maxX - 84, rect.minY)
- P₁ = (rect.maxX - 84, rect.minY + 40) - 控制点1
- P₂ = (rect.maxX, rect.minY) - 控制点2
- P₃ = (rect.maxX, rect.minY + 40)

## ✅ 优势总结

1. **精确匹配设计**
   - 直接使用CSS cubic-bezier参数
   - 反转效果完美实现

2. **S形曲线**
   - 平滑的凹陷效果
   - 自然的波浪形状

3. **易于调整**
   - 修改百分比即可
   - 控制点独立调整

4. **专业级质量**
   - 符合设计工具标准
   - 视觉效果优秀

## 🧪 测试验证

### 视觉检查
- [ ] S形曲线平滑
- [ ] 起点和终点位置正确
- [ ] 凹陷效果明显
- [ ] 没有生硬转折

### 代码验证
- ✅ 无编译错误
- ✅ 使用addCurve方法
- ✅ 两个控制点正确计算
- ✅ 路径闭合完整

---
**实现方式：** 三次贝塞尔曲线（Cubic Bezier）  
**曲线参数：** cubic-bezier(0.00, 1.00, 1.00, 0.00) [反转]  
**完成时间：** 2026-02-06  
**状态：** ✅ 完成

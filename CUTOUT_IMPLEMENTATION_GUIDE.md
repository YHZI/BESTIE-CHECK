# TextBar 缺口实现指南

## 🎯 什么是缺口

缺口（Cutout）是指在气泡框的右上角挖出一个L形区域，为将来可能放置的元素（如头像、图标等）预留空间。

## 📐 当前缺口配置

### 缺口参数
```swift
struct CutoutPositionCalculator {
    static let cutoutWidth: CGFloat = 84   // 缺口宽度
    static let cutoutHeight: CGFloat = 40  // 缺口高度
}
```

### 缺口位置
- **位置：** 气泡框的右上角
- **形状：** L形（垂直边 + 水平边）
- **尺寸：** 84pt（宽）× 40pt（高）

## 🎨 缺口的绘制原理

### 1. 定义缺口区域
```swift
let topRightCutout = CutoutPositionCalculator.getCutoutRect(in: rect)

// 返回的CGRect：
// x: rect.maxX - 84  （从右边界向左84pt）
// y: rect.minY       （从顶部开始）
// width: 84pt
// height: 40pt
```

### 2. 绘制气泡路径
路径绘制顺序（顺时针）：
```
1. 左上角圆角
2. 上边线 → 到缺口起点
3. L形缺口垂直边 ↓（向下40pt）
4. L形缺口水平边 →（向右84pt）
5. 右边线 ↓
6. 右下角圆角
7. 底边线 ←
8. 左下角圆角
9. 左边线 ↑
10. 闭合路径
```

## 💻 核心代码实现

### BubbleWithLCutout Shape

```swift
struct BubbleWithLCutout: Shape {
    var cornerRadius: CGFloat = 18
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // 1. 获取缺口区域
        let topRightCutout = CutoutPositionCalculator.getCutoutRect(in: rect)
        
        // 2. 起点：左上角圆角后
        path.move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
        
        // 3. 上边线（到缺口起点）
        path.addLine(to: CGPoint(x: topRightCutout.minX, y: rect.minY))
        
        // 4. L形缺口 - 垂直边
        path.addLine(to: CGPoint(x: topRightCutout.minX, y: topRightCutout.maxY))
        
        // 5. L形缺口 - 水平边
        path.addLine(to: CGPoint(x: rect.maxX, y: topRightCutout.maxY))
        
        // 6-10. 其余边和圆角...
        
        path.closeSubpath()
        return path
    }
}
```

## 📊 视觉示意图

```
┌──────────────────────┐
│              ┌───────┤ ← 缺口开始（topRightCutout.minX, rect.minY）
│              │       │
│  Text        │ 40pt  │ ← 缺口高度
│  Content     │       │
│              └───────┤ ← 缺口结束（rect.maxX, topRightCutout.maxY）
│                      │
│                      │
└──────────────────────┘
       ↑       ↑
    84pt宽度   缺口区域
```

## 🔧 如何修改缺口

### 1. 修改缺口尺寸
```swift
struct CutoutPositionCalculator {
    static let cutoutWidth: CGFloat = 100   // 改为100pt宽
    static let cutoutHeight: CGFloat = 60   // 改为60pt高
}
```

### 2. 修改缺口位置
目前缺口在右上角，如果要改为其他位置：

**左上角缺口：**
```swift
static func getCutoutRect(in rect: CGRect) -> CGRect {
    CGRect(
        x: rect.minX,           // 从左边界开始
        y: rect.minY,
        width: cutoutWidth,
        height: cutoutHeight
    )
}
```

**右下角缺口：**
```swift
static func getCutoutRect(in rect: CGRect) -> CGRect {
    CGRect(
        x: rect.maxX - cutoutWidth,
        y: rect.maxY - cutoutHeight,  // 从底部向上
        width: cutoutWidth,
        height: cutoutHeight
    )
}
```

### 3. 修改缺口形状

**改为圆角缺口：**
```swift
// 在缺口转角处添加圆角
path.addArc(
    center: CGPoint(x: topRightCutout.minX + radius, y: topRightCutout.maxY - radius),
    radius: radius,
    startAngle: Angle(degrees: 180),
    endAngle: Angle(degrees: 270),
    clockwise: false
)
```

## 🎯 使用场景

### 1. 放置头像
```swift
ZStack(alignment: .topTrailing) {
    ReactTextBar(text: "消息内容")
    
    // 头像放在缺口位置
    Image("avatar")
        .resizable()
        .frame(width: 80, height: 80)
        .clipShape(Circle())
        .offset(x: -42, y: -20)  // 根据缺口位置调整
}
```

### 2. 放置图标
```swift
ZStack(alignment: .topTrailing) {
    ReactTextBar(text: "消息内容")
    
    // 图标放在缺口位置
    Image(systemName: "star.fill")
        .foregroundColor(.yellow)
        .font(.system(size: 30))
        .offset(x: -42, y: 20)
}
```

### 3. 放置按钮
```swift
ZStack(alignment: .topTrailing) {
    ReactTextBar(text: "消息内容")
    
    // 关闭按钮
    Button(action: { /* 关闭 */ }) {
        Image(systemName: "xmark.circle.fill")
            .font(.system(size: 24))
    }
    .offset(x: -42, y: 20)
}
```

## 📐 计算器的作用

### CutoutPositionCalculator
这是一个统一管理缺口位置的工具类：

**优势：**
- ✅ 集中管理缺口参数
- ✅ 修改一处，全局更新
- ✅ 易于维护和调试

**提供的功能：**
```swift
// 1. 缺口尺寸参数
cutoutWidth: 84pt
cutoutHeight: 40pt

// 2. 获取缺口区域
getCutoutRect(in: rect) -> CGRect
```

## ✅ 当前实现特点

1. **简洁明了**
   - 只保留缺口相关代码
   - 删除了圆形组件的复杂计算

2. **易于扩展**
   - 可以轻松添加其他元素到缺口位置
   - 计算器提供统一的位置信息

3. **性能优化**
   - 无需额外的ZStack层
   - 直接在Shape中绘制缺口

## 🎨 完整示例

### 基础使用
```swift
ReactTextBar(text: "Sorry! No face detected in AR scan.")
```

### 自定义样式
```swift
ReactTextBar(
    text: "Custom message",
    backgroundColor: Color.blue.opacity(0.2),
    textColor: .white
)
```

### 配合其他元素
```swift
ZStack(alignment: .topTrailing) {
    ReactTextBar(text: "消息")
    
    // 在缺口位置添加任何你想要的元素
    YourCustomView()
        .offset(x: -42, y: 20)
}
```

## 📝 注意事项

1. **缺口尺寸** - 确保缺口足够大以容纳你要放置的元素
2. **元素定位** - 使用offset时要考虑元素的中心点位置
3. **响应式设计** - 在不同屏幕尺寸上测试缺口效果

---
**文档创建时间：** 2026-02-06  
**版本：** 1.0  
**状态：** ✅ 完整实现

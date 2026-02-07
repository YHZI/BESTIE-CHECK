# LogoFrame 图像位置调整指南

## 新增参数

LogoFrame现在支持三个可调节参数：

### 1. horizontalOffset (水平偏移)
- **类型**: `CGFloat`
- **默认值**: `0`
- **作用**: 调整图像的水平位置
- **方向**: 
  - **正值** → 向右移动
  - **负值** → 向左移动
  - **0** → 居中（无偏移）

### 2. verticalOffset (垂直偏移)
- **类型**: `CGFloat`
- **默认值**: `0`
- **作用**: 调整图像的垂直位置
- **方向**:
  - **正值** → 向下移动
  - **负值** → 向上移动
  - **0** → 居中（无偏移）

### 3. imageScale (图像缩放)
- **类型**: `CGFloat`
- **默认值**: `1.2`
- **作用**: 调整图像的缩放比例
- **范围**:
  - **1.0** → 原始大小
  - **> 1.0** → 放大
  - **< 1.0** → 缩小

## 使用方法

### 基础使用（默认值）
```swift
LogoFrame()
```

### 调整水平位置
```swift
// 向右移动5pt
LogoFrame(horizontalOffset: 5)

// 向左移动5pt
LogoFrame(horizontalOffset: -5)
```

### 调整垂直位置
```swift
// 向下移动3pt
LogoFrame(verticalOffset: 3)

// 向上移动3pt
LogoFrame(verticalOffset: -3)
```

### 同时调整水平和垂直
```swift
LogoFrame(
    horizontalOffset: 5,   // 向右5pt
    verticalOffset: -3     // 向上3pt
)
```

### 完整参数示例
```swift
LogoFrame(
    horizontalOffset: 2,    // 向右2pt
    verticalOffset: -1,     // 向上1pt
    imageScale: 1.3         // 放大到1.3倍
)
```

## 在ContentView中的应用

```swift
ZStack(alignment: .topTrailing) {
    // 气泡框
    ReactTextBarWithCircle(text: viewModel.bubbleText)
    
    // LogoFrame 圆形叠加在气泡上
    LogoFrame(
        horizontalOffset: 0,   // 水平居中
        verticalOffset: 0,     // 垂直居中
        imageScale: 1.2        // 当前缩放刚好
    )
    .frame(height: 120)
}
```

## 调整建议

### 如何找到完美的位置

#### 步骤1: 检查当前位置
运行应用，查看Logo在圆形中的位置

#### 步骤2: 调整水平位置
- Logo偏左？增加`horizontalOffset`（例如：2, 3, 5）
- Logo偏右？减少`horizontalOffset`（例如：-2, -3, -5）

#### 步骤3: 调整垂直位置
- Logo偏上？增加`verticalOffset`（例如：2, 3, 5）
- Logo偏下？减少`verticalOffset`（例如：-2, -3, -5）

#### 步骤4: 微调
以1pt为单位微调，直到完美居中

### 常见调整场景

**场景1: Logo偏左上**
```swift
LogoFrame(
    horizontalOffset: 3,   // 向右3pt
    verticalOffset: 2      // 向下2pt
)
```

**场景2: Logo偏右下**
```swift
LogoFrame(
    horizontalOffset: -3,  // 向左3pt
    verticalOffset: -2     // 向上2pt
)
```

**场景3: Logo太小需要放大**
```swift
LogoFrame(
    imageScale: 1.5        // 放大到1.5倍
)
```

**场景4: Logo太大需要缩小**
```swift
LogoFrame(
    imageScale: 1.0        // 缩小到1.0倍
)
```

## 调试技巧

### 1. 临时添加参考线
```swift
Circle()
    .stroke(Color.red, lineWidth: 1)  // 红色圆形参考线
    .frame(width: 56, height: 56)
```

### 2. 显示坐标信息
```swift
Text("Offset: (\(horizontalOffset), \(verticalOffset))")
    .font(.caption)
```

### 3. 使用Slider动态调整（开发时）
```swift
struct LogoFrameDebugView: View {
    @State private var hOffset: CGFloat = 0
    @State private var vOffset: CGFloat = 0
    @State private var scale: CGFloat = 1.2
    
    var body: some View {
        VStack {
            LogoFrame(
                horizontalOffset: hOffset,
                verticalOffset: vOffset,
                imageScale: scale
            )
            
            VStack {
                HStack {
                    Text("H: \(hOffset, specifier: "%.1f")")
                    Slider(value: $hOffset, in: -10...10)
                }
                HStack {
                    Text("V: \(vOffset, specifier: "%.1f")")
                    Slider(value: $vOffset, in: -10...10)
                }
                HStack {
                    Text("Scale: \(scale, specifier: "%.1f")")
                    Slider(value: $scale, in: 0.5...2.0)
                }
            }
            .padding()
        }
    }
}
```

## 参数范围建议

| 参数 | 推荐范围 | 说明 |
|------|----------|------|
| horizontalOffset | -10 ~ 10 | 超过10pt可能偏移过大 |
| verticalOffset | -10 ~ 10 | 超过10pt可能偏移过大 |
| imageScale | 0.8 ~ 2.0 | 太小看不清，太大超出边界 |

## 实现原理

### offset修饰符
```swift
.offset(x: horizontalOffset, y: verticalOffset)
```
- 作用于Image
- 在Circle内部移动
- 配合`clipShape(Circle())`确保不超出边界

### scaleEffect修饰符
```swift
.scaleEffect(imageScale)
```
- 以中心点为基准缩放
- 先缩放后偏移（顺序很重要）
- 放大后可能需要调整偏移来补偿

## 当前配置（默认值）

```swift
LogoFrame(
    horizontalOffset: 0,   // 居中
    verticalOffset: 0,     // 居中
    imageScale: 1.2        // 当前缩放刚好
)
```

**下一步：**
根据实际显示效果，调整`horizontalOffset`和`verticalOffset`值，直到图像完美居中。

---
**创建时间：** 2026-02-07  
**功能：** 图像位置微调  
**状态：** ✅ 已实现

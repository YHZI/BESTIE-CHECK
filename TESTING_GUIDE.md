# 快速测试指南

## 🎯 如何测试气泡框

### 最简单的方法：使用测试按钮
1. 打开 Xcode
2. 运行应用 (⌘R)
3. 点击屏幕底部的蓝色 **"Test Bubble"** 按钮
4. 气泡应该立即出现在屏幕顶部
5. 点击气泡右侧的 ❌ 按钮关闭

### 预期效果
```
✅ 气泡出现在屏幕顶部
✅ 气泡右上角有L形缺口
✅ 关闭按钮(X)位于缺口区域
✅ 气泡显示文字："Sorry! No face detected in AR scan."
✅ 点击X可以关闭气泡
```

## 🔍 故障排查

### 如果气泡没有显示：

#### 1. 清理并重建
```bash
# 在终端中执行
cd /Users/in4matx_inst/INF191/BESTIE-CHECK
rm -rf ~/Library/Developer/Xcode/DerivedData/Bestie-Check-*
```
然后在 Xcode 中：
- Product > Clean Build Folder (⇧⌘K)
- Product > Build (⌘B)
- Product > Run (⌘R)

#### 2. 检查文件包含
在 Xcode 中：
1. 选择 `compoent.swift` 文件
2. 打开右侧 File Inspector (⌥⌘1)
3. 确保 "Target Membership" 中 "Bestie-Check" 已勾选

#### 3. 重启 Xcode
- 完全退出 Xcode
- 重新打开项目
- 再次运行

#### 4. 使用Preview测试
1. 打开 `TestReactTextBar.swift`
2. 在 Canvas 中查看 Preview
3. 如果 Preview 显示正常，说明组件工作正常

## 📱 在真机上测试

### 相机权限
如果在真机上测试，需要确保：
1. Info.plist 中有相机权限描述
2. 首次运行时授予相机权限
3. AR会话正确初始化

### 测试步骤
1. 连接 iPhone 到 Mac
2. 在 Xcode 中选择你的设备
3. 运行应用
4. 授予相机权限
5. 点击 "Test Bubble" 按钮

## 🎨 自定义气泡样式

### 修改颜色
在 `ContentView.swift` 第25行：
```swift
// 默认
ReactTextBar(text: viewModel.bubbleText)

// 自定义颜色
ReactTextBar(
    text: viewModel.bubbleText,
    backgroundColor: Color.blue.opacity(0.3),
    textColor: .white
)
```

### 修改缺口大小
在 `compoent.swift` BubbleWithLCutout 的 path 方法中修改：
```swift
// 当前：缺口为组件的一半
let cutoutWidth = rect.width / 2
let cutoutHeight = rect.height / 2

// 示例：缺口为组件的1/3
let cutoutWidth = rect.width / 3
let cutoutHeight = rect.height / 3
```

## 📊 代码检查清单

- [x] ✅ `compoent.swift` 存在且正确
- [x] ✅ `ReactTextBar` 组件已定义
- [x] ✅ `BubbleWithLCutout` Shape 已定义
- [x] ✅ `ContentView.swift` 使用 `ReactTextBar`
- [x] ✅ `FaceMeshAssistantViewModel` 有测试方法
- [x] ✅ 测试按钮已添加
- [x] ✅ 无编译错误

## 🐛 常见问题

### Q: 点击测试按钮后气泡没出现
A: 检查 ViewModel 的 `isBubbleVisible` 状态：
- 在 `triggerTestBubble()` 方法中添加 print 语句
- 确认方法被调用

### Q: 气泡出现但没有L形缺口
A: 检查 `BubbleWithLCutout` 的 path 方法
- 使用 `TestReactTextBar.swift` 独立测试
- 在 Preview 中查看效果

### Q: 关闭按钮位置不对
A: 调整 ContentView 中的 offset：
```swift
.offset(x: -8, y: 0)  // 调整 x 和 y 值
```

## 📞 技术支持

如果以上方法都不起作用：
1. 查看 `DIAGNOSTIC_REPORT.md` 获取详细诊断
2. 检查 Xcode 控制台是否有错误信息
3. 确认 iOS 部署目标版本匹配

---
最后更新：2026-02-06

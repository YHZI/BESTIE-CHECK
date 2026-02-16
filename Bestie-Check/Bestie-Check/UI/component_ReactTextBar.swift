//
//  component_ReactTextBar.swift
//  Bestie-Check
//
//  Created by in4matx_inst on 2/6/26.
//  ReactTextBar和气泡相关的组件实现
//

import SwiftUI

// MARK: - 模版类型
/// ReactTextBar 的显示模版
enum ReactTextBarTemplate {
    case template1  // 模版1：仅显示内容（无标题、无分割线）
    case template2  // 模版2：完整显示（标题 + 分割线 + 内容）
}

// MARK: - ReactTextBar 组合组件
/// 带有漂浮圆形的气泡框组合组件（水平居中）
struct ReactTextBarWithCircle: View {
    let title: String
    let text: String
    var titleColor: Color = .primary
    var textColor: Color = .secondary
    @Binding var isExpanded: Bool  // 添加绑定来暴露展开状态
    var showBackButton: Bool = false  // 是否显示返回按钮
    var onBackTapped: (() -> Void)?  // 返回按钮回调
    
    var body: some View {
        HStack {
            Spacer()
            BubbleContent(
                title: title,
                text: text,
                titleColor: titleColor,
                textColor: textColor,
                isExpanded: $isExpanded,
                showBackButton: showBackButton,
                onBackTapped: onBackTapped
            )
            .onChange(of: text) { oldValue, newValue in
                print("📝 ReactTextBarWithCircle: text changed")
                print("   Old length: \(oldValue.count), New length: \(newValue.count)")
                print("   First 50 chars: \(String(newValue.prefix(50)))")
            }
            Spacer()
        }
    }
}

// MARK: - ReactTextBar 组件（保留用于兼容）
/// 带有右上角L形缺口的气泡框组件
struct ReactTextBar: View {
    let title: String
    let text: String
    var titleColor: Color = .primary
    var textColor: Color = .secondary
    var showBackButton: Bool = false  // 是否显示返回按钮
    var onBackTapped: (() -> Void)?  // 返回按钮回调
    @State private var isExpandedLocal: Bool = false
    
    var body: some View {
        BubbleContent(
            title: title,
            text: text,
            titleColor: titleColor,
            textColor: textColor,
            isExpanded: $isExpandedLocal,
            showBackButton: showBackButton,
            onBackTapped: onBackTapped
        )
    }
    
    /// 重置/初始化 ReactTextBar 的状态
    func reset() {
        withAnimation {
            isExpandedLocal = false
        }
    }
}

// MARK: - 气泡内容（内部共用组件）
/// 气泡框的内容部分，避免重复代码
private struct BubbleContent: View {
    let title: String
    let text: String
    var titleColor: Color = .primary
    var textColor: Color = .secondary
    @Binding var isExpanded: Bool
    var showBackButton: Bool = false
    var onBackTapped: (() -> Void)?
    
    private let bubbleColor = Color(red: 0xEC/255, green: 0xEF/255, blue: 0xF3/255)
    
    @State private var screenHeight: CGFloat = 0
    @State private var contentReady: Bool = false  // 内容是否准备好渲染
    @State private var shouldShowContent: Bool = false  // 是否显示完整内容
    @State private var previousText: String = ""  // 追踪文本变化
    @State private var displayedText: String = ""  // 打字机效果：当前显示的文本
    @State private var isTyping: Bool = false  // 是否正在打字
    @State private var typingTaskId: UUID = UUID()  // 打字任务ID，用于取消
    @State private var textOpacity: Double = 0.0  // 文本透明度，用于淡入效果
    @State private var shouldExpand: Bool = false  // 是否应该展开（基于文本长度预判）
    @State private var textLengthCache: Int = 0  // 文本长度缓存
    
    // 根据展开状态自动选择模版
    private var currentTemplate: ReactTextBarTemplate {
        isExpanded ? .template2 : .template1
    }
    
    // 预判文本是否需要展开（基于长度而非布局计算）
    private func shouldTextExpand(_ text: String) -> Bool {
        // 保守估算：假设每行约40个字符，行高约20pt
        // 可用高度约80pt（120 - 标题 - 分割线 - padding）
        // 约可容纳4行，即160个字符
        let estimatedShouldExpand = text.count > 160
        print("📏 Quick estimate: text length \(text.count), should expand: \(estimatedShouldExpand)")
        return estimatedShouldExpand
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    // 标题部分（始终存在，通过 opacity 控制显示）
                    GeometryReader { titleGeometry in
                        let availableWidth = titleGeometry.size.width - CutoutPositionCalculator.cutoutWidth
                        let titleOffset = -CutoutPositionCalculator.cutoutWidth / 2
                        
                        Text(title.isEmpty ? " " : title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(titleColor)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(width: availableWidth, height: CutoutPositionCalculator.cutoutHeight, alignment: .center)
                            .offset(x: titleOffset)
                            .frame(width: titleGeometry.size.width, height: titleGeometry.size.height, alignment: .center)
                    }
                    .frame(height: CutoutPositionCalculator.cutoutHeight)
                    .opacity(currentTemplate == .template2 ? 1.0 : 0.0)
                    
                    // 分割线（始终存在，通过 opacity 控制显示）
                    Divider()
                        .background(Color.gray.opacity(0.3))
                        .padding(.horizontal, 16)
                        .opacity(currentTemplate == .template2 ? 1.0 : 0.0)
                
                    // 预留空白
                    Spacer()
                        .frame(height: 8)
                
                    // 文本部分（动态高度，展开时可滚动）
                    if isExpanded {
                        // 展开状态：使用打字机效果渐进显示文本
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(displayedText.isEmpty ? " " : displayedText)
                                    .font(.system(size: 16))
                                    .foregroundColor(textColor)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 0)
                                    .padding(.bottom, 12)
                            }
                        }
                        .frame(maxHeight: .infinity)
                        .opacity(textOpacity)
                    } else {
                        // 未展开状态：优化渲染，避免昂贵的布局计算
                        if currentTemplate == .template1 {
                            VStack(spacing: 0) {
                                Spacer()
                                
                                Group {
                                    if text.count > 200 {
                                        Text(String(text.prefix(150)) + "...")
                                            .font(.system(size: 16))
                                            .foregroundColor(textColor)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(4)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .padding(.horizontal, 16)
                                    } else {
                                        Text(text.isEmpty ? " " : text)
                                            .font(.system(size: 16))
                                            .foregroundColor(textColor)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(4)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .padding(.horizontal, 16)
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    
                    Spacer()
                }
                .frame(minHeight: 120, alignment: .top)
                .frame(maxHeight: isExpanded ? calculateMaxHeight(screenHeight: screenHeight) : 120, alignment: .top)
                .background(
                    BubbleWithLCutout()
                        .fill(bubbleColor.opacity(isExpanded ? 0.7 : 0.4))
                )
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
                .onChange(of: isExpanded) { oldValue, newValue in
                    print("🔄 isExpanded changed: \(oldValue) → \(newValue)")
                    if newValue {
                        print("⚡ Bubble expanding, waiting for animation to complete...")
                        cancelTyping()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            print("✅ Bubble expansion completed, starting typewriter effect")
                            startTypewriterEffect(fullText: text)
                        }
                    } else {
                        print("⚡ Cancelling typing and resetting displayed text")
                        cancelTyping()
                        displayedText = ""
                        textOpacity = 0.0
                    }
                }
                .onChange(of: text) { oldValue, newValue in
                    print("📝 BubbleContent: text changed (in body)")
                    print("   Old length: \(oldValue.count), New length: \(newValue.count)")
                    print("   isExpanded: \(isExpanded)")
                    
                    if previousText != newValue {
                        print("🔄 Text changed from '\(previousText.prefix(20))...' to '\(newValue.prefix(20))...'")
                        previousText = newValue
                        textLengthCache = newValue.count
                        
                        let needsExpansion = shouldTextExpand(newValue)
                        
                        if needsExpansion && !isExpanded {
                            print("🚀 Quick expansion triggered by text length")
                            shouldExpand = true
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isExpanded = true
                            }
                        } else if isExpanded {
                            print("🔄 Already expanded, restarting typewriter effect")
                            cancelTyping()
                            displayedText = ""
                            textOpacity = 0.0
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                startTypewriterEffect(fullText: newValue)
                            }
                        }
                    }
                }
                .onAppear {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        screenHeight = windowScene.screen.bounds.height
                        print("🖥️ Screen height from hardware: \(screenHeight)pt")
                    }
                    previousText = text
                    textLengthCache = text.count
                    print("📱 BubbleContent appeared with text length: \(text.count)")
                    print("📱 Initial state - isExpanded: \(isExpanded)")
                    
                    shouldExpand = shouldTextExpand(text)
                    
                    if shouldExpand && !isExpanded {
                        print("🚀 Initial expansion triggered by text length")
                        DispatchQueue.main.async {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isExpanded = true
                            }
                        }
                    } else if isExpanded && !text.isEmpty {
                        print("⚡ View appeared with isExpanded=true, waiting before typewriter")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            startTypewriterEffect(fullText: text)
                        }
                    }
                }
                
                // 返回按钮（左上角）
                if showBackButton {
                    BackButton(diameter: 22) {
                        handleBackTapped()
                    }
                    .padding(.leading, 16)
                    .padding(.top, 12)
                }
            }
        }
    }
    private func cancelTyping() {
        if isTyping {
            print("🛑 Cancelling current typing task (ID: \(typingTaskId))")
            typingTaskId = UUID()  // 生成新ID，使旧任务失效
            isTyping = false
        }
    }
    
    /// 启动打字机效果
    private func startTypewriterEffect(fullText: String) {
        guard !isTyping else {
            print("⏸️ Typewriter already running, skipping")
            return
        }
        
        isTyping = true
        displayedText = ""
        textOpacity = 0.0  // 初始透明
        
        // 生成新的任务ID
        let currentTaskId = UUID()
        typingTaskId = currentTaskId
        
        print("⌨️ Starting typewriter effect (Task ID: \(currentTaskId))")
        print("   Full text length: \(fullText.count)")
        
        // 先淡入显示区域
        withAnimation(.easeIn(duration: 0.3)) {
            textOpacity = 1.0
        }
        
        // 分片策略：优化性能，使用更大的分片
        let chunkSize = 100  // 每次显示100个字符（减少渲染次数）
        let delay: TimeInterval = 0.025  // 每块之间的延迟（25ms，更快）
        
        let characters = Array(fullText)
        var currentIndex = 0
        
        func typeNextChunk() {
            // 检查任务是否被取消
            guard currentTaskId == typingTaskId else {
                print("🚫 Typing task cancelled (ID mismatch)")
                return
            }
            
            guard currentIndex < characters.count else {
                print("✅ Typewriter effect completed (Task ID: \(currentTaskId))")
                isTyping = false
                return
            }
            
            // 计算本次要添加的字符数
            let endIndex = min(currentIndex + chunkSize, characters.count)
            let chunk = String(characters[currentIndex..<endIndex])
            
            // 更新显示的文本
            displayedText += chunk
            currentIndex = endIndex
            
            // 继续下一块
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                typeNextChunk()
            }
        }
        
        // 开始打字
        typeNextChunk()
    }
    
    /// 处理返回按钮点击 - 重置状态
    private func handleBackTapped() {
        // 重置展开状态，使用快速弹簧动画
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isExpanded = false
        }
        
        // 调用外部回调
        onBackTapped?()
        
        print("🔄 ReactTextBar reset: isExpanded = false")
    }
    
    // 计算扩展时的最大高度
    private func calculateMaxHeight(screenHeight: CGFloat) -> CGFloat {
        guard screenHeight > 0 else { return .infinity }
        // 气泡框最大高度 = 屏幕高度 - 顶部padding(60) - DebugPanel空间(100) - 底部边距(20)
        // 为 DebugPanel 预留足够空间，防止遮挡
        let debugPanelSpace: CGFloat = 100  // DebugPanel 预留空间
        let maxHeight = screenHeight - 60 - debugPanelSpace - 20
        print("🎈 Calculated max height: \(maxHeight)pt (Screen: \(screenHeight)pt, Reserved for Debug: \(debugPanelSpace)pt)")
        return maxHeight
    }
}

// MARK: - PreferenceKey for Text Height
private struct TextHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - 缺口位置计算器
struct CutoutPositionCalculator {
    static let cutoutWidth: CGFloat = 84
    static let cutoutHeight: CGFloat = 40
    
    static func getCutoutRect(in rect: CGRect) -> CGRect {
        CGRect(
            x: rect.maxX - cutoutWidth,
            y: rect.minY,
            width: cutoutWidth,
            height: cutoutHeight
        )
    }
}

// MARK: - L形缺口气泡形状
/// 在右上角有直角L形缺口的气泡框形状
/// 参考CSS样式：大圆角设计
struct BubbleWithLCutout: Shape {
    var cornerRadius: CGFloat = 36  // 气泡四角的大圆角
    
    func path(in rect: CGRect) -> Path {
        // 获取缺口区域参数
        let cutoutWidth = CutoutPositionCalculator.cutoutWidth
        let cutoutHeight = CutoutPositionCalculator.cutoutHeight
        
        // 使用 rect 的实际高度（由外部 VStack 的 frame 控制）
        let actualBottom = rect.maxY
        
        print("🎨 Drawing bubble - rect height: \(rect.height)pt, bottom: \(actualBottom)pt")
        
        return Path { path in
            // 1. 起点：左上角
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
            
            // 2. 左上圆角（大圆角）
            path.addArc(
                center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: Angle(degrees: 180),
                endAngle: Angle(degrees: 270),
                clockwise: false
            )
            
            // 3. 上边线（直线到缺口圆角起点）
            let cutoutCornerRadius: CGFloat = 18  // 缺口圆角半径
            path.addLine(to: CGPoint(x: rect.maxX - cutoutWidth - cutoutCornerRadius, y: rect.minY))
            
            // 4. 缺口圆角1（从上边线到垂直边的平滑过渡）
            path.addArc(
                center: CGPoint(x: rect.maxX - cutoutWidth - cutoutCornerRadius, y: rect.minY + cutoutCornerRadius),
                radius: cutoutCornerRadius,
                startAngle: Angle(degrees: 270),
                endAngle: Angle(degrees: 0),
                clockwise: false
            )
            
            // 5. 缺口垂直边（向下到圆角起点）
            path.addLine(to: CGPoint(x: rect.maxX - cutoutWidth, y: rect.minY + cutoutHeight - cutoutCornerRadius))
            
            // 6. 缺口圆角2（从垂直边到水平边，向内凹）
            path.addArc(
                center: CGPoint(x: rect.maxX - cutoutWidth + 1 * cutoutCornerRadius, y: rect.minY + cutoutHeight - cutoutCornerRadius),
                radius: cutoutCornerRadius,
                startAngle: Angle(degrees: 180),
                endAngle: Angle(degrees: 90),
                clockwise: true
            )
            
            // 7. 缺口水平边（向右）
            let cutoutCornerRadiusBig : CGFloat = 28
            path.addLine(to: CGPoint(x: rect.maxX - cutoutCornerRadiusBig, y: rect.minY + cutoutHeight))
            
            // 8. 缺口圆角3（水平->垂直）
            path.addArc(
                center: CGPoint(x: rect.maxX - cutoutCornerRadiusBig, y: rect.minY + cutoutHeight + cutoutCornerRadiusBig),
                radius: cutoutCornerRadiusBig,
                startAngle: Angle(degrees: 270),
                endAngle: Angle(degrees: 0),
                clockwise: false
            )
            
            // 9. 右边线（直线向下到底部）
            path.addLine(to: CGPoint(x: rect.maxX, y: actualBottom - cornerRadius))
            
            // 10. 右下圆角（大圆角）
            path.addArc(
                center: CGPoint(x: rect.maxX - cornerRadius, y: actualBottom - cornerRadius),
                radius: cornerRadius,
                startAngle: Angle(degrees: 0),
                endAngle: Angle(degrees: 90),
                clockwise: false
            )
            
            // 11. 底边线（直线向左）
            path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: actualBottom))
            
            // 12. 左下圆角（大圆角）
            path.addArc(
                center: CGPoint(x: rect.minX + cornerRadius, y: actualBottom - cornerRadius),
                radius: cornerRadius,
                startAngle: Angle(degrees: 90),
                endAngle: Angle(degrees: 180),
                clockwise: false
            )
            
            // 13. 左边线（直线向上）
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
            
            // 14. 闭合路径
            path.closeSubpath()
        }
    }
}

// MARK: - Preview
#Preview("模版演示") {
    VStack(spacing: 30) {
        Text("模版1：缩起状态（仅内容，居中）")
            .font(.caption)
            .foregroundColor(.white)
        
        // 模版1：短文本（仅显示内容）
        ReactTextBar(title: "Title (Hidden)", text: "Hello! 😊")
            .frame(height: 120)
            .padding()
        
        Divider().background(Color.white)
        
        Text("模版2：展开状态（标题 + 分割线 + 内容）")
            .font(.caption)
            .foregroundColor(.white)
        
        // 模版2：长文本测试（显示完整组件）
        ReactTextBar(
            title: "Important Notice",
            text: """
This is a very long text that should trigger the responsive behavior. When the text exceeds the default frame size, the bubble should extend its right edge line all the way down to near the bottom of the screen.

The template will automatically switch from Template 1 (content only) to Template 2 (title + divider + content) when expanded.

Additional content to demonstrate the scrolling behavior in expanded mode. The title and divider will appear smoothly with animation.
""",
            titleColor: .blue,
            textColor: .primary
        )
        .frame(height: 500)
        .padding()
        
        Spacer()
    }
    .background(Color.black)
}

#Preview("模版1 - 仅内容") {
    VStack(spacing: 20) {
        Text("模版1示例：缩起状态")
            .font(.headline)
            .foregroundColor(.white)
        
        ReactTextBar(title: "", text: "Hello! 😊")
            .frame(height: 120)
            .padding()
        
        ReactTextBar(title: "", text: "This is a short message.")
            .frame(height: 120)
            .padding()
        
        Spacer()
    }
    .background(Color.black)
}

#Preview("模版2 - 完整显示") {
    ScrollView {
        VStack(spacing: 20) {
            Text("模版2示例：展开状态")
                .font(.headline)
                .foregroundColor(.white)
            
            ReactTextBar(
                title: "Warning",
                text: """
This is a long text that triggers expansion. The template will show:
- Title at the top
- Divider line
- Content below with scrolling

All components are fully visible in expanded mode.
""",
                titleColor: .red,
                textColor: .primary
            )
            .frame(height: 400)
            .padding()
            
            Spacer()
        }
    }
    .background(Color.black)
}

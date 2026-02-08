//
//  component_ReactTextBar.swift
//  Bestie-Check
//
//  Created by in4matx_inst on 2/6/26.
//  ReactTextBar和气泡相关的组件实现
//

import SwiftUI

// MARK: - ReactTextBar 组合组件
/// 带有漂浮圆形的气泡框组合组件（水平居中）
struct ReactTextBarWithCircle: View {
    let title: String
    let text: String
    var titleColor: Color = .primary
    var textColor: Color = .secondary
    @Binding var isExpanded: Bool  // 添加绑定来暴露展开状态
    
    var body: some View {
        HStack {
            Spacer()
            BubbleContent(title: title, text: text, titleColor: titleColor, textColor: textColor, isExpanded: $isExpanded)
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
    @State private var isExpandedLocal: Bool = false
    
    var body: some View {
        BubbleContent(title: title, text: text, titleColor: titleColor, textColor: textColor, isExpanded: $isExpandedLocal)
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
    
    private let bubbleColor = Color(red: 0xEC/255, green: 0xEF/255, blue: 0xF3/255)
    
    @State private var screenHeight: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                // 标题部分（在气泡框内部，分割线上方，水平和垂直居中，不包含缺口区域）
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
                
                // 分割线（淡灰色）
                Divider()
                    .background(Color.gray.opacity(0.3))
                    .padding(.horizontal, 16)
                
                // 预留空白
                Spacer()
                    .frame(height: 8)
                
                // 文本部分（动态高度）
                Text(text.isEmpty ? " " : text)
                    .font(.system(size: 16))
                    .foregroundColor(textColor)
                    .fixedSize(horizontal: false, vertical: true)  // 允许垂直方向自然扩展
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 16)
                    .padding(.top, 0)
                    .padding(.bottom, 12)
                    .background(
                        GeometryReader { textGeometry in
                            Color.clear.preference(
                                key: TextHeightPreferenceKey.self,
                                value: textGeometry.size.height
                            )
                        }
                    )
                    .onPreferenceChange(TextHeightPreferenceKey.self) { height in
                        // 检查文本是否超出默认高度（触发响应式）
                        // 计算：标题(40) + 分割线间距 + 空白(8) + 文本高度 + 文本底部padding(12)
                        let totalHeight = CutoutPositionCalculator.cutoutHeight + 1 + 8 + height + 12
                        let newExpandedState = totalHeight > 120
                        
                        // 调试输出
                        print("📏 Text height: \(height)pt, Total: \(totalHeight)pt, Expanded: \(newExpandedState)")
                        
                        if isExpanded != newExpandedState {
                            isExpanded = newExpandedState
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
            .onAppear {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    screenHeight = windowScene.screen.bounds.height
                    print("🖥️ Screen height from hardware: \(screenHeight)pt")
                }
            }
        }
    }
    
    // 计算扩展时的最大高度
    private func calculateMaxHeight(screenHeight: CGFloat) -> CGFloat {
        guard screenHeight > 0 else { return .infinity }
        // 气泡框最大高度 = 屏幕高度 - 顶部padding(60) - 底部边距(20)
        let maxHeight = screenHeight - 60 - 20
        print("🎈 Calculated max height: \(maxHeight)pt (Screen: \(screenHeight)pt)")
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
#Preview("ReactTextBar") {
    VStack(spacing: 20) {
        // 短文本测试（空标题，短文本）
        ReactTextBar(title: "", text: "Hello! 😊")
            .frame(height: 120)
            .padding()
        
        // 中等文本测试（带标题）
        ReactTextBar(title: "Warning", text: "Sorry! No face detected in AR scan.")
            .frame(height: 150)
            .padding()
        
        // 长文本测试 - 应该扩展到接近屏幕底部，触发70%透明度
        ReactTextBar(
            title: "Important Notice",
            text: "This is a very long text that should trigger the responsive behavior. When the text exceeds the default frame size, the bubble should extend its right edge line all the way down to near the bottom of the screen, creating a taller bubble shape while maintaining the L-shaped cutout at the top right corner. The background opacity should change to 70%.",
            titleColor: .blue,
            textColor: .blue
        )
        .frame(height: 500)  // 模拟长文本
        .padding()
        
        // 空白测试（标题和文本都为空）
        ReactTextBar(title: "", text: "")
            .frame(height: 120)
            .padding()
        
        Spacer()
    }
    .background(Color.black)
}

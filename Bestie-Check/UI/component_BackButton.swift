//
//  component_BackButton.swift
//  Bestie-Check
//
//  Created by in4matx_inst on 2/8/26.
//  返回按钮组件实现
//

import SwiftUI

/// MARK: - BackButton
/// 返回按钮：白色圆形背景（直径22）+ 中心的返回箭头符号
/// 具有智能功能：根据 ReactTextBar 展开状态自动处理重置逻辑
struct BackButton: View {
    var diameter: CGFloat = 22
    var action: () -> Void = {}
    
    // 智能功能接口
    @Binding var isTextBarExpanded: Bool?  // ReactTextBar 展开状态（可选）
    var onResetDetection: (() -> Void)?  // 重置 APP 后台检测方法的接口
    @Binding var isLongTextMode: Bool?  // 长文本模式状态（可选，与 DebugPanel 同步）
    
    @State private var isPressed: Bool = false
    
    // 初始化器 - 简单模式（仅自定义 action）
    init(diameter: CGFloat = 22, action: @escaping () -> Void = {}) {
        self.diameter = diameter
        self.action = action
        self._isTextBarExpanded = .constant(nil)
        self.onResetDetection = nil
        self._isLongTextMode = .constant(nil)
    }
    
    // 初始化器 - 智能模式（自动处理 ReactTextBar 状态）
    init(diameter: CGFloat = 22, 
         isTextBarExpanded: Binding<Bool?>,
         onResetDetection: (() -> Void)? = nil,
         isLongTextMode: Binding<Bool?>? = nil,
         action: @escaping () -> Void = {}) {
        self.diameter = diameter
        self._isTextBarExpanded = isTextBarExpanded
        self.onResetDetection = onResetDetection
        self._isLongTextMode = isLongTextMode ?? .constant(nil)
        self.action = action
    }
    
    var body: some View {
        Button(action: handleButtonTap) {
            ZStack {
                // 白色圆形背景
                Circle()
                    .fill(Color.white)
                    .frame(width: diameter, height: diameter)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // 返回箭头符号
                BackArrowShape()
                    .stroke(Color.black, lineWidth: 1.5)
                    .frame(width: diameter * 0.45, height: diameter * 0.45)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .opacity(isPressed ? 0.7 : 1.0)
            // Ensure minimum tap target without changing visual size.
            .frame(width: max(44, diameter), height: max(44, diameter))
            .contentShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }

    /// 处理按钮点击，根据 ReactTextBar 状态自动执行相应操作
    private func handleButtonTap() {
        // 检查是否启用智能模式
        if let expanded = isTextBarExpanded {
            if expanded {
                // ReactTextBar 处于展开状态
                print("🔄 BackButton: ReactTextBar is expanded, resetting...")
                
                // 1. 重置 ReactTextBar 状态
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isTextBarExpanded = false
                }
                
                // 2. 重置 LongTextMode（如果提供）
                if let _ = isLongTextMode {
                    withAnimation {
                        isLongTextMode = false
                    }
                    print("🔄 BackButton: LongTextMode reset to false")
                }
                
                // 3. 调用后台检测重置接口（如果提供）
                onResetDetection?()
                
                // 4. 执行自定义 action
                action()
                
                print("✅ BackButton: Reset completed")
            } else {
                // ReactTextBar 未展开，仅执行自定义 action
                print("ℹ️ BackButton: ReactTextBar not expanded, executing custom action only")
                action()
            }
        } else {
            // 简单模式，仅执行自定义 action
            action()
        }
    }
}

// MARK: - BackArrowShape
/// 返回箭头的矢量形状（指向左边的箭头）
struct BackArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            let width = rect.width
            let height = rect.height
            
            // 箭头由三部分组成：
            // 1. 上方斜线（从右上到左中）
            // 2. 下方斜线（从左中到右下）
            // 3. 水平线（从左中到右中）
            
            // 起点：左边中心点
            let leftCenter = CGPoint(x: 0, y: height / 2)
            
            // 上方点：右上
            let topRight = CGPoint(x: width * 0.5, y: 0)
            
            // 下方点：右下
            let bottomRight = CGPoint(x: width * 0.5, y: height)
            
            // 右边中心点（水平线终点）
            let rightCenter = CGPoint(x: width, y: height / 2)
            
            // 绘制上方斜线
            path.move(to: topRight)
            path.addLine(to: leftCenter)
            
            // 绘制下方斜线
            path.addLine(to: bottomRight)
            
            // 绘制水平线
            path.move(to: leftCenter)
            path.addLine(to: rightCenter)
        }
    }
}

// MARK: - Preview
struct BackButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.3)
            BackButton {
                print("Back button tapped")
            }
        }
    }
}

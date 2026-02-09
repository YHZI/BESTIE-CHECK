//
//  component_viewFinder.swift
//  Bestie-Check
//
//  Created by in4matx_inst on 2/7/26.
//

import SwiftUI

// MARK: - ViewFinder 组件
// 用于在界面上绘制一个取景框，用来指示用户对脸部的捕捉

struct ViewFinder: View {
    var frameWidth: CGFloat = 280
    var frameHeight: CGFloat = 360
    var cornerLength: CGFloat = 30
    var lineWidth: CGFloat = 3
    var color: Color = .white
    var animating: Bool = false
    var showScanLine: Bool = false  // 扫描线开关，默认关闭
    var faceDetected: Bool = false  // 人脸检测状态，默认未检测到
    
    var body: some View {
        ZStack {
            // 半透明背景遮罩（四周变暗，中间透明）
            ViewFinderMask(
                frameWidth: frameWidth,
                frameHeight: frameHeight
            )
            
            // 取景框的四个角（带人脸检测动画）
            ViewFinderCorners(
                frameWidth: frameWidth,
                frameHeight: frameHeight,
                cornerLength: cornerLength,
                lineWidth: lineWidth,
                color: color,
                faceDetected: faceDetected
            )
            
            // 扫描线动画：仅在检测到人脸且开关开启时显示
            if faceDetected && showScanLine {
                ViewFinderScanLine(
                    frameWidth: frameWidth,
                    frameHeight: frameHeight,
                    color: color
                )
            }
        }
    }
}

// MARK: - ViewFinder 遮罩
/// 创建中间透明、四周半透明的遮罩效果
struct ViewFinderMask: View {
    var frameWidth: CGFloat
    var frameHeight: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 全屏半透明黑色背景
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                
                // 中间透明矩形（使用反向遮罩）
                Rectangle()
                    .frame(width: frameWidth, height: frameHeight)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        }
    }
}

// MARK: - ViewFinder 四个角
/// 绘制取景框的四个转角线条（带人脸检测扩散动画）
struct ViewFinderCorners: View {
    var frameWidth: CGFloat
    var frameHeight: CGFloat
    var cornerLength: CGFloat
    var lineWidth: CGFloat
    var color: Color
    var faceDetected: Bool = false
    
    @State private var expandOffset: CGFloat = 0
    @State private var animationID: UUID = UUID()  // 用于取消动画的 ID
    
    var body: some View {
        ZStack {
            // 左上角
            CornerShape(position: .topLeft, length: cornerLength)
                .stroke(color, lineWidth: lineWidth)
                .offset(x: -expandOffset, y: -expandOffset)
            
            // 右上角
            CornerShape(position: .topRight, length: cornerLength)
                .stroke(color, lineWidth: lineWidth)
                .offset(x: expandOffset, y: -expandOffset)
            
            // 左下角
            CornerShape(position: .bottomLeft, length: cornerLength)
                .stroke(color, lineWidth: lineWidth)
                .offset(x: -expandOffset, y: expandOffset)
            
            // 右下角
            CornerShape(position: .bottomRight, length: cornerLength)
                .stroke(color, lineWidth: lineWidth)
                .offset(x: expandOffset, y: expandOffset)
        }
        .frame(width: frameWidth, height: frameHeight)
        .onChange(of: faceDetected) { oldValue, newValue in
            if !newValue {
                // 未检测到人脸时，触发扩散动画
                triggerExpandAnimation()
            } else {
                // 检测到人脸时，取消所有动画并复原
                cancelAllAnimations()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    expandOffset = 0
                }
            }
        }
        .onAppear {
            if !faceDetected {
                triggerExpandAnimation()
            }
        }
    }
    
    /// 取消所有排队的动画
    private func cancelAllAnimations() {
        // 更新 animationID，使所有基于旧 ID 的异步任务失效
        animationID = UUID()
        print("🛑 ViewFinder: Cancelled all expand animations")
    }
    
    /// 触发扩散动画（扩散后快速复原）
    private func triggerExpandAnimation() {
        // 捕获当前的 animationID
        let currentAnimationID = animationID
        
        // 扩散阶段
        withAnimation(.easeOut(duration: 0.6)) {
            expandOffset = 15  // 向外扩散15pt
        }
        
        // 复原阶段（延迟0.6秒后执行）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [currentAnimationID] in
            // 检查动画是否已被取消
            guard currentAnimationID == animationID else {
                print("🚫 ViewFinder: Animation cancelled (expand phase)")
                return
            }
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                expandOffset = 0
            }
            
            // 循环：如果仍未检测到人脸，1.5秒后再次触发
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [currentAnimationID] in
                // 检查动画是否已被取消
                guard currentAnimationID == animationID else {
                    print("🚫 ViewFinder: Animation cancelled (loop phase)")
                    return
                }
                
                if !faceDetected {
                    triggerExpandAnimation()
                }
            }
        }
    }
}

// MARK: - 角落形状
/// 绘制单个角落的L形状
struct CornerShape: Shape {
    enum Position {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    var position: Position
    var length: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        switch position {
        case .topLeft:
            // 水平线（左上）
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
            // 垂直线（左上）
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + length))
            
        case .topRight:
            // 水平线（右上）
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.minY))
            // 垂直线（右上）
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))
            
        case .bottomLeft:
            // 水平线（左下）
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + length, y: rect.maxY))
            // 垂直线（左下）
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))
            
        case .bottomRight:
            // 水平线（右下）
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
            // 垂直线（右下）
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        }
        
        return path
    }
}

// MARK: - 扫描线动画
/// 从上到下的循环扫描线动画效果
struct ViewFinderScanLine: View {
    var frameWidth: CGFloat
    var frameHeight: CGFloat
    var color: Color
    
    @State private var offsetY: CGFloat = 0
    
    var body: some View {
        ZStack {
            // 扫描线渐变效果
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            color.opacity(0),
                            color.opacity(0.6),
                            color.opacity(0.8),
                            color.opacity(0.6),
                            color.opacity(0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: frameWidth, height: 4)
                .blur(radius: 1)
                .offset(y: offsetY)
        }
        .frame(width: frameWidth, height: frameHeight)
        .clipped()
        .onAppear {
            startScanAnimation()
        }
    }
    
    /// 启动循环扫描动画（来回往复）
    private func startScanAnimation() {
        // 初始位置：框顶部
        offsetY = -frameHeight / 2
        
        // 扫描动画：从上到下，然后从下到上，周期性来回
        withAnimation(
            Animation.linear(duration: 2.0)
                .repeatForever(autoreverses: true)
        ) {
            offsetY = frameHeight / 2
        }
    }
}

// MARK: - Preview
#Preview("未检测到人脸 - 扩散提醒") {
    ZStack {
        // 模拟相机背景
        Color.gray.ignoresSafeArea()
        
        // ViewFinder 组件 - 未检测到人脸，显示四角扩散动画提醒
        ViewFinder(
            frameWidth: 280,
            frameHeight: 360,
            cornerLength: 30,
            lineWidth: 3,
            color: .white,
            showScanLine: false,
            faceDetected: false
        )
    }
}

#Preview("检测到人脸 - 开始扫描") {
    ZStack {
        // 模拟相机背景
        Color.gray.ignoresSafeArea()
        
        // ViewFinder 组件 - 检测到人脸，绿色，显示扫描线
        ViewFinder(
            frameWidth: 280,
            frameHeight: 360,
            cornerLength: 30,
            lineWidth: 3,
            color: .green,
            showScanLine: true,
            faceDetected: true
        )
    }
}

#Preview("检测到人脸 - 无扫描线") {
    ZStack {
        // 模拟相机背景
        Color.gray.ignoresSafeArea()
        
        // ViewFinder 组件 - 检测到人脸，绿色，扫描线开关关闭
        ViewFinder(
            frameWidth: 280,
            frameHeight: 360,
            cornerLength: 30,
            lineWidth: 3,
            color: .green,
            showScanLine: false,
            faceDetected: true
        )
    }
}

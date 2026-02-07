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
    
    var body: some View {
        ZStack {
            // 半透明背景遮罩（四周变暗，中间透明）
            ViewFinderMask(
                frameWidth: frameWidth,
                frameHeight: frameHeight
            )
            
            // 取景框的四个角
            ViewFinderCorners(
                frameWidth: frameWidth,
                frameHeight: frameHeight,
                cornerLength: cornerLength,
                lineWidth: lineWidth,
                color: color
            )
            
            // 扫描线动画（可选）
            if animating {
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
/// 绘制取景框的四个转角线条
struct ViewFinderCorners: View {
    var frameWidth: CGFloat
    var frameHeight: CGFloat
    var cornerLength: CGFloat
    var lineWidth: CGFloat
    var color: Color
    
    var body: some View {
        ZStack {
            // 左上角
            CornerShape(position: .topLeft, length: cornerLength)
                .stroke(color, lineWidth: lineWidth)
            
            // 右上角
            CornerShape(position: .topRight, length: cornerLength)
                .stroke(color, lineWidth: lineWidth)
            
            // 左下角
            CornerShape(position: .bottomLeft, length: cornerLength)
                .stroke(color, lineWidth: lineWidth)
            
            // 右下角
            CornerShape(position: .bottomRight, length: cornerLength)
                .stroke(color, lineWidth: lineWidth)
        }
        .frame(width: frameWidth, height: frameHeight)
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
/// 从上到下的扫描线动画效果
struct ViewFinderScanLine: View {
    var frameWidth: CGFloat
    var frameHeight: CGFloat
    var color: Color
    
    @State private var offsetY: CGFloat = 0
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        color.opacity(0),
                        color.opacity(0.5),
                        color.opacity(0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: frameWidth, height: 3)
            .offset(y: offsetY)
            .onAppear {
                // 循环动画
                withAnimation(
                    Animation.linear(duration: 2.0)
                        .repeatForever(autoreverses: false)
                ) {
                    offsetY = frameHeight / 2
                }
            }
            .frame(width: frameWidth, height: frameHeight)
            .clipped()
            .offset(y: -frameHeight / 4)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        // 模拟相机背景
        Color.gray.ignoresSafeArea()
        
        // ViewFinder 组件
        ViewFinder(
            frameWidth: 280,
            frameHeight: 360,
            cornerLength: 30,
            lineWidth: 3,
            color: .green,
            animating: true
        )
    }
}

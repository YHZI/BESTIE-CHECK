//
//  compoent.swift
//  Bestie-Check
//
//  Created by in4matx_inst on 2/6/26.
//

import SwiftUI

// MARK: - ReactTextBar 组合组件
/// 带有漂浮圆形的气泡框组合组件（水平居中）
struct ReactTextBarWithCircle: View {
    let text: String
    var backgroundColor: Color = Color(.systemGray5)
    var textColor: Color = .primary
    
    var body: some View {
        HStack {
            Spacer() // 左侧弹簧
            
            // 气泡框（不带圆形）
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(textColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(height: 120, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    BubbleWithLCutout()
                        .fill(backgroundColor)
                )
            
            Spacer() // 右侧弹簧
        }
    }
}

// MARK: - ReactTextBar 组件（保留用于兼容）
/// 带有右上角L形缺口的气泡框组件
struct ReactTextBar: View {
    let text: String
    var backgroundColor: Color = Color(.systemGray5)
    var textColor: Color = .primary
    
    var body: some View {
        // 气泡框（不带圆形）
        Text(text)
            .font(.system(size: 16))
            .foregroundColor(textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(height: 120, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                BubbleWithLCutout()
                    .fill(backgroundColor)
            )
    }
}

// MARK: - 缺口位置计算器
/// 计算缺口的位置关系（统一计算逻辑）
struct CutoutPositionCalculator {
    // MARK: - 核心参数（所有计算的基础）
    static let cutoutWidth: CGFloat = 84  // 缺口宽度
    static let cutoutHeight: CGFloat = 40  // 缺口高度
    
    // MARK: - 位置计算方法
    
    /// 获取缺口区域（在Shape的rect坐标系中）
    /// - Parameter rect: Shape的绘制区域
    /// - Returns: 缺口的CGRect区域
    static func getCutoutRect(in rect: CGRect) -> CGRect {
        CGRect(
            x: rect.maxX - cutoutWidth,  // 从右边界向左
            y: rect.minY,                // 从顶部开始
            width: cutoutWidth,          // 84pt
            height: cutoutHeight         // 40pt
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
                startAngle: Angle(degrees: 270),  // 从上方开始
                endAngle: Angle(degrees: 0),      // 到右侧结束
                clockwise: false
            )
            
            // 5. 缺口垂直边（向下到圆角起点）
            path.addLine(to: CGPoint(x: rect.maxX - cutoutWidth, y: rect.minY + cutoutHeight - cutoutCornerRadius))
            
            // 6. 缺口圆角2（从垂直边到水平边，向内凹）
            // 圆心在bar外部
            path.addArc(
                center: CGPoint(x: rect.maxX - cutoutWidth + 1 * cutoutCornerRadius, y: rect.minY + cutoutHeight - cutoutCornerRadius),
                radius: cutoutCornerRadius,
                startAngle: Angle(degrees: 180),
                endAngle: Angle(degrees: 90),
                clockwise: true
            )
            
            // 7. 缺口水平边（向右）
            path.addLine(to: CGPoint(x: rect.maxX - cutoutCornerRadius, y: rect.minY + cutoutHeight))
            
            // 缺口圆角 （水平->垂直）
            path.addArc(
                center: CGPoint(x: rect.maxX - cutoutCornerRadius, y: rect.minY + cutoutHeight + cutoutCornerRadius),
                radius: cutoutCornerRadius,
                startAngle: Angle(degrees: 270),
                endAngle: Angle(degrees: 0),
                clockwise: false
            )
            
            
            // 8. 右边线（直线向下）
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius + cutoutCornerRadius))
            
            // 9. 右下圆角（大圆角）
            path.addArc(
                center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: Angle(degrees: 0),
                endAngle: Angle(degrees: 90),
                clockwise: false
            )
            
            // 10. 底边线（直线向左）
            path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
            
            // 11. 左下圆角（大圆角）
            path.addArc(
                center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: Angle(degrees: 90),
                endAngle: Angle(degrees: 180),
                clockwise: false
            )
            
            // 12. 左边线（直线向上）
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
            
            // 13. 闭合路径
            path.closeSubpath()
        }
    }
}

struct LogoFrame: Shape {
    func path(in rect: CGRect) -> Path {
        let position = getPos(in: rect)
        let logoRadius: CGFloat = 21
        
        return Path { path in
            // 以计算的圆心位置画一个圆
            path.addEllipse(in: CGRect(
                x: position.x - logoRadius,
                y: position.y - logoRadius,
                width: logoRadius * 2,
                height: logoRadius * 2
            ))
        }
    }
    
    func getPos(in rect: CGRect) -> CGPoint {
        let logoRadius: CGFloat = 21
        let x = rect.maxX - CutoutPositionCalculator.cutoutWidth / 2 - 3
        let y = rect.minY - x + 3
        
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Preview
#Preview("ReactTextBar") {
    VStack(spacing: 20) {
        ReactTextBar(text: "Sorry! No face detected in AR scan.")
            .padding()
        
        ReactTextBar(
            text: "This is a bubble with L-cutout",
            backgroundColor: Color.blue.opacity(0.2),
            textColor: .blue
        )
        .padding()
        
        ReactTextBar(
            text: "Hello! 😊",
            backgroundColor: Color.green.opacity(0.2),
            textColor: .green
        )
        .padding()
    }
    .background(Color.black)
}

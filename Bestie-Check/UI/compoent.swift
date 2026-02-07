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
            Spacer()
            BubbleContent(text: text, backgroundColor: backgroundColor, textColor: textColor)
            Spacer()
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
        BubbleContent(text: text, backgroundColor: backgroundColor, textColor: textColor)
    }
}

// MARK: - 气泡内容（内部共用组件）
/// 气泡框的内容部分，避免重复代码
private struct BubbleContent: View {
    let text: String
    var backgroundColor: Color
    var textColor: Color
    
    var body: some View {
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

// MARK: - ARIcon 眼睛构件（直接使用SVG Path数据）

/// AR图标的缩放辅助结构
private struct ARIconScale {
    let scaleX: CGFloat
    let scaleY: CGFloat
    
    init(in rect: CGRect) {
        self.scaleX = rect.width / 63.0
        self.scaleY = rect.height / 73.0
    }
    
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * scaleX, y: y * scaleY)
    }
}

/// AR图标的眼眶（使用SVG原始path数据）
struct ARIconEyeSocket: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = ARIconScale(in: rect)
        
        return Path { path in
            // 直接使用SVG的path数据：
            // M31.4454 24.4276C24.4494 24.3113 17.2139 29.1986 12.6651 34.2056...
            
            // 起点
            path.move(to: scale.point(31.4454, 24.4276))
            
            // 第一段贝塞尔曲线（左侧眼眶）
            path.addCurve(
                to: scale.point(12.6651, 34.2056),
                control1: scale.point(24.4494, 24.3113),
                control2: scale.point(17.2139, 29.1986)
            )
            
            // 左下曲线
            path.addCurve(
                to: scale.point(12.6651, 38.069),
                control1: scale.point(12.1876, 34.7357),
                control2: scale.point(11.9234, 36.8507)
            )
            
            // 底部曲线
            path.addCurve(
                to: scale.point(31.4454, 47.854),
                control1: scale.point(17.1133, 42.9701),
                control2: scale.point(24.3297, 47.972)
            )
            
            // 右侧曲线
            path.addCurve(
                to: scale.point(50.231, 38.069),
                control1: scale.point(38.5612, 47.972),
                control2: scale.point(45.7776, 42.9701)
            )
            
            // 右上曲线
            path.addCurve(
                to: scale.point(50.231, 34.2056),
                control1: scale.point(50.7084, 37.5389),
                control2: scale.point(50.9727, 35.4239)
            )
            
            // 顶部曲线回到起点
            path.addCurve(
                to: scale.point(31.4454, 24.4276),
                control1: scale.point(45.6769, 29.1986),
                control2: scale.point(38.4414, 24.3113)
            )
        }
    }
}

/// AR图标的瞳孔（使用SVG原始path数据，可移动）
struct ARIconPupil: Shape {
    var position: CGPoint = CGPoint(x: 0.5, y: 0.5)  // 相对位置（0-1）
    var offsetRange: CGFloat = 3.0  // 瞳孔可移动的范围
    
    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 63.0
        let scaleY = rect.height / 73.0
        
        // 瞳孔移动偏移
        let offsetX = (position.x - 0.5) * offsetRange * scaleX
        let offsetY = (position.y - 0.5) * offsetRange * scaleY
        
        return Path { path in
            // 直接使用SVG的瞳孔path数据（添加偏移）
            let centerX = 31.4462 * scaleX + offsetX
            let centerY = 36.1416 * scaleY + offsetY
            let radius = (36.2579 - 31.4462) * scaleX  // 瞳孔半径
            
            // 使用四段贝塞尔曲线绘制圆形
            let k = 0.5522847498  // 圆形的贝塞尔曲线常数
            
            // 右侧起点
            path.move(to: CGPoint(x: centerX + radius, y: centerY))
            
            // 右下
            path.addCurve(
                to: CGPoint(x: centerX, y: centerY + radius),
                control1: CGPoint(x: centerX + radius, y: centerY + radius * k),
                control2: CGPoint(x: centerX + radius * k, y: centerY + radius)
            )
            
            // 左下
            path.addCurve(
                to: CGPoint(x: centerX - radius, y: centerY),
                control1: CGPoint(x: centerX - radius * k, y: centerY + radius),
                control2: CGPoint(x: centerX - radius, y: centerY + radius * k)
            )
            
            // 左上
            path.addCurve(
                to: CGPoint(x: centerX, y: centerY - radius),
                control1: CGPoint(x: centerX - radius, y: centerY - radius * k),
                control2: CGPoint(x: centerX - radius * k, y: centerY - radius)
            )
            
            // 右上
            path.addCurve(
                to: CGPoint(x: centerX + radius, y: centerY),
                control1: CGPoint(x: centerX + radius * k, y: centerY - radius),
                control2: CGPoint(x: centerX + radius, y: centerY - radius * k)
            )
        }
    }
}

/// AR图标视图 - 完整的AR扫描图标
struct ARIconView: View {
    var pupilPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)  // 瞳孔位置（0-1，0.5为居中）
    var eyeSocketColor: Color = .black
    var pupilColor: Color = .black
    var strokeWidth: CGFloat = 3.5
    var showDecorations: Bool = true  // 是否显示周围的装饰线条
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 周围的装饰线条（如果需要）
                if showDecorations {
                    ARIconDecorations()
                        .stroke(eyeSocketColor, lineWidth: strokeWidth)
                }
                
                // 眼眶
                ARIconEyeSocket()
                    .stroke(eyeSocketColor, lineWidth: strokeWidth)
                
                // 瞳孔
                ARIconPupil(position: pupilPosition)
                    .stroke(pupilColor, lineWidth: strokeWidth)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

/// AR图标的装饰线条（周围的扫描线）
struct ARIconDecorations: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = ARIconScale(in: rect)
        
        return Path { path in
            // 顶部垂直线
            path.move(to: scale.point(31.4455, 1.72778))
            path.addLine(to: scale.point(31.4455, 11.3933))
            
            // 底部垂直线
            path.move(to: scale.point(31.4455, 60.8875))
            path.addLine(to: scale.point(31.4455, 70.553))
            
            // 左上对角线
            path.move(to: scale.point(11.1825, 22.9646))
            path.addLine(to: scale.point(2.81193, 18.1318))
            
            // 左下对角线
            path.move(to: scale.point(11.1825, 49.3171))
            path.addLine(to: scale.point(2.81193, 54.1499))
            
            // 右上对角线
            path.move(to: scale.point(52.7973, 22.9646))
            path.addLine(to: scale.point(61.1679, 18.1318))
            
            // 右下对角线
            path.move(to: scale.point(52.7973, 49.3171))
            path.addLine(to: scale.point(61.1679, 54.1499))
            
            // 顶部角线组
            path.move(to: scale.point(23.627, 5.84411))
            path.addLine(to: scale.point(31.448, 1.72778))
            path.addLine(to: scale.point(39.269, 5.84411))
            
            // 底部角线组
            path.move(to: scale.point(23.627, 66.4368))
            path.addLine(to: scale.point(31.448, 70.5531))
            path.addLine(to: scale.point(39.269, 66.4368))
            
            // 右上角连接线
            path.move(to: scale.point(53.3465, 13.2537))
            path.addLine(to: scale.point(61.1675, 17.37))
            path.addLine(to: scale.point(61.1675, 26.7552))
            
            // 右下角连接线
            path.move(to: scale.point(53.3465, 59.0272))
            path.addLine(to: scale.point(61.1675, 54.9109))
            path.addLine(to: scale.point(61.1675, 45.5256))
            
            // 左上角连接线
            path.move(to: scale.point(9.54883, 13.2537))
            path.addLine(to: scale.point(1.72781, 17.37))
            path.addLine(to: scale.point(1.72781, 26.7552))
            
            // 左下角连接线
            path.move(to: scale.point(9.54883, 59.0272))
            path.addLine(to: scale.point(1.72781, 54.9109))
            path.addLine(to: scale.point(1.72781, 45.5256))
        }
    }
}

// MARK: - LogoFrame
/// 在缺口位置显示Logo的圆形框架
struct LogoFrame: View {
    var horizontalOffset: CGFloat = 0  // 水平偏移（正值向右，负值向左）
    var verticalOffset: CGFloat = 0    // 垂直偏移（正值向下，负值向上）
    var imageScale: CGFloat = 1.2      // 图像缩放比例
    
    var body: some View {
        GeometryReader { geometry in
            let position = getPos(in: geometry.frame(in: .local))
            let logoRadius: CGFloat = 28
            
            // 圆形容器，内部填充SVG图像
            Circle()
                .fill(Color.white)
                .frame(width: logoRadius * 2, height: logoRadius * 2)
                .overlay(
                    Image("LogoIcon")
                        .renderingMode(.original)  // 保留原始渲染模式
                        .resizable()
                        .aspectRatio(contentMode: .fill)  // 使用fill模式填充整个区域
                        .frame(width: logoRadius * 2, height: logoRadius * 2)
                        .clipShape(Circle())  // 裁剪成圆形
                        .scaleEffect(imageScale)  // 可调节的缩放
                        .offset(x: horizontalOffset, y: verticalOffset)  // 可调节的偏移
                )
                .overlay(
                    Circle()
                        .stroke(Color.blue, lineWidth: 2)
                )
                .position(position)
        }
    }
    
    func getPos(in rect: CGRect) -> CGPoint {
        // 圆心应该在缺口的中心位置
        // X: 缺口中心的X坐标
        let x = rect.maxX - CutoutPositionCalculator.cutoutWidth / 2
        // Y: 缺口中心的Y坐标（从顶部开始）
        let y = rect.minY + CutoutPositionCalculator.cutoutHeight / 8
        
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

#Preview("ARIconView") {
    VStack(spacing: 30) {
        // 基础AR图标
        ARIconView()
            .frame(width: 63, height: 73)
        
        // 瞳孔向右看
        ARIconView(pupilPosition: CGPoint(x: 0.7, y: 0.5))
            .frame(width: 63, height: 73)
        
        // 瞳孔向左看
        ARIconView(pupilPosition: CGPoint(x: 0.3, y: 0.5))
            .frame(width: 63, height: 73)
        
        // 瞳孔向上看
        ARIconView(pupilPosition: CGPoint(x: 0.5, y: 0.3))
            .frame(width: 63, height: 73)
        
        // 白色AR图标（不显示装饰线）
        ARIconView(
            eyeSocketColor: .white,
            pupilColor: .white,
            showDecorations: false
        )
        .frame(width: 50, height: 58)
        .background(Color.black)
        
        // 动画示例
        ARIconAnimatedView()
            .frame(width: 63, height: 73)
    }
    .padding()
}

/// AR图标动画示例 - 瞳孔自动移动
struct ARIconAnimatedView: View {
    @State private var pupilPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)
    
    var body: some View {
        ARIconView(pupilPosition: pupilPosition)
            .onAppear {
                // 瞳孔循环移动动画
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    pupilPosition = CGPoint(x: 0.7, y: 0.3)
                }
            }
    }
}

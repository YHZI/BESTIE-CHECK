//
//  component_ARIcon.swift
//  Bestie-Check
//
//  Created by in4matx_inst on 2/7/26.
//  AR Icon相关的组件实现
//

import SwiftUI

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

// MARK: - Preview
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

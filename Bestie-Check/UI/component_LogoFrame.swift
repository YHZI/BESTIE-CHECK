//
//  component_LogoFrame.swift
//  Bestie-Check
//
//  Created by in4matx_inst on 2/7/26.
//  LogoFrame相关的组件实现
//

import SwiftUI

// MARK: - LogoFrame
/// 在缺口位置显示Logo的圆形框架
/// isGlowing — FunFact 收起后亮起呼吸灯，引导用户点击重新唤出
/// onTap     — 点击 Logo 圆圈的回调
struct LogoFrame: View {
    var horizontalOffset: CGFloat = 12  // 水平偏移（正值向右，负值向左）
    var verticalOffset: CGFloat = 0    // 垂直偏移（正值向下，负值向上）
    var imageScale: CGFloat = 0.18    // 图像缩放比例（< 1 以确保 SVG 不溢出圆形边框）
    var isGlowing: Bool = false        // 是否发光
    var onTap: (() -> Void)? = nil     // 点击回调

    var body: some View {
        GeometryReader { geometry in
            let position   = getPos(in: geometry.frame(in: .local))
            let logoRadius: CGFloat = 28
            let diameter = logoRadius * 2
            let iconSide = diameter * imageScale

            ZStack {
                // ── Breathing glow (behind the circle) ──────────────────
                if isGlowing {
                    FunFactBreathingGlow(radius: logoRadius)
                        .position(position)
                }

                // ── Transparent circle + AppIcon SVG (centered, no white fill) ──
                Circle()
                    .fill(Color.clear)
                    .frame(width: diameter, height: diameter)
                    .overlay(
                        Image("AppIconImage")
                            .renderingMode(.original)
                            .resizable()
                            .aspectRatio(contentMode: .fit)          // 保持宽高比，整体内缩
                            .frame(width: iconSide, height: iconSide) // 比圆框小一圈，绝不溢出
                            .offset(x: horizontalOffset, y: verticalOffset)
                    )
                    .overlay(
                        Circle().stroke(
                            isGlowing
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [
                                        Color(red: 0x69/255.0, green: 0xAC/255.0, blue: 0x14/255.0),
                                        Color(red: 0x49/255.0, green: 0x3D/255.0, blue: 0x89/255.0),
                                        Color(red: 0xF8/255.0, green: 0x4C/255.0, blue: 0x4C/255.0),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                : AnyShapeStyle(Color.blue),
                            lineWidth: isGlowing ? 2.5 : 2
                        )
                    )
                    .scaleEffect(isGlowing ? 1.08 : 1.0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isGlowing)
                    .position(position)
                    .onTapGesture { onTap?() }
            }
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
#Preview("LogoFrame") {
    ZStack {
        Color.gray.opacity(0.3)
        
        VStack(spacing: 20) {
            // 基础LogoFrame
            LogoFrame()
                .frame(width: 300, height: 120)
            
            // 调整偏移的LogoFrame
            LogoFrame(
                horizontalOffset: 5,
                verticalOffset: -2,
                imageScale: 1.5
            )
            .frame(width: 300, height: 120)
            
            // 发光效果的LogoFrame示例
            LogoFrame(isGlowing: true, onTap: { print("tapped") })
                .frame(width: 300, height: 120)
        }
    }
}

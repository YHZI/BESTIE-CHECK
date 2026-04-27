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
    var horizontalOffset: CGFloat = -6  // 水平偏移（正值向右，负值向左）
    var verticalOffset: CGFloat = 0    // 垂直偏移（正值向下，负值向上）
    var imageScale: CGFloat = 1.2      // 图像缩放比例
    var isGlowing: Bool = false        // 是否发光
    var onTap: (() -> Void)? = nil     // 点击回调

    var body: some View {
        GeometryReader { geometry in
            let position   = getPos(in: geometry.frame(in: .local))
            let logoRadius: CGFloat = 28

            ZStack {
                // ── Breathing glow (behind the circle) ──────────────────
                if isGlowing {
                    FunFactBreathingGlow(radius: logoRadius)
                        .position(position)
                }

                // ── White circle + LogoIcon ──────────────────────────────
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

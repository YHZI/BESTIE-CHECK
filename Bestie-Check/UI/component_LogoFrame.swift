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
struct LogoFrame: View {
    var horizontalOffset: CGFloat = -6  // 水平偏移（正值向右，负值向左）
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
        }
    }
}

//
//  component_funFact.swift
//  Bestie-Check
//
//  Created by in4matx_inst on 4/27/26.
//

import SwiftUI

// MARK: - FunFactBubble

/// 布局：[气泡 →尾巴][LaunchIcon + 关闭按钮]
/// 功能：记忆上次关闭位置，下次在原位置打开
struct FunFactBubble: View {
    let text: String
    var feedbackText: String? = nil
    var onDismiss: (() -> Void)? = nil

    @State private var isCollapsed:   Bool    = false
    @State private var bubbleScale:   CGFloat = 0.0
    @State private var bubbleOpacity: Double  = 0.0
    @State private var glowOpacity:   Double  = 0.0
    @State private var position:      CGSize  = .zero
    @GestureState private var dragDelta: CGSize = .zero
    @State private var hasLoadedSavedPosition: Bool = false
    @State private var isExpanded:    Bool    = false  // 气泡展开状态（显示完整文本）

    // 持久化位置存储
    @AppStorage("funFactBubbleX") private var savedX: Double = 0
    @AppStorage("funFactBubbleY") private var savedY: Double = 0
    @AppStorage("funFactHasSavedPosition") private var hasSavedPosition: Bool = false

    private let iconSize: CGFloat = 44

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 0) {
                if !isCollapsed {
                    bubbleContent
                        .scaleEffect(bubbleScale, anchor: .trailing)
                        .opacity(bubbleOpacity)
                        .transition(.identity)
                }
                iconViewWithClose
            }
            .position(
                x: geo.size.width / 2 + position.width + dragDelta.width,
                y: geo.size.height / 2 + position.height + dragDelta.height
            )
            .gesture(
                DragGesture()
                    .updating($dragDelta) { v, state, _ in state = v.translation }
                    .onEnded { v in
                        position.width  += v.translation.width
                        position.height += v.translation.height
                        // 实时保存位置
                        savePosition()
                    }
            )
            .onAppear {
                // 每次出现时重置状态（修复重新打开时不显示的 bug）
                isCollapsed = false
                glowOpacity = 0.0  // 重置呼吸灯透明度
                
                // 只在第一次加载时读取保存的位置
                if !hasLoadedSavedPosition {
                    hasLoadedSavedPosition = true
                    loadInitialPosition(screenSize: geo.size)
                }
                
                // 每次都执行展开动画
                expand()
            }
        }
    }

    // MARK: - Bubble content

    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, feedbackText == nil ? 10 : 4)
                .frame(maxWidth: 200, alignment: .leading)

            if let fb = feedbackText, !fb.isEmpty {
                Text(fb)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(isExpanded ? nil : 2)  // 展开时不限制行数，否则最多2行
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                    .frame(maxWidth: isExpanded ? 280 : 200, alignment: .leading)
                
                // 展开/收起提示（只在有文本且可展开时显示）
                if fb.count > 50 {  // 大约2行文本的字符数
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                        Text(isExpanded ? "Tap to collapse" : "Tap to expand")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.blue.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                }
            }
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.45), lineWidth: 1)
            }
        )
        .overlay(alignment: .trailing) {
            RightTail()
                .fill(.ultraThinMaterial)
                .frame(width: 10, height: 8)
                .offset(x: 9, y: 0)
        }
        .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            // 点击气泡切换展开/收起状态
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                isExpanded.toggle()
            }
        }
    }

    // MARK: - Icon with close button

    private var iconViewWithClose: some View {
        ZStack(alignment: .topTrailing) {
            // 章鱼图标
            ZStack {
                if isCollapsed {
                    FunFactBreathingGlow(radius: iconSize / 2)
                        .opacity(glowOpacity)
                }
                Image("LaunchIcon")
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
            }

            // 关闭按钮（右上角）
            Button { collapse() } label: {
                ZStack {
                    Circle()
                        .fill(Color(uiColor: .systemBackground).opacity(0.92))
                        .frame(width: 18, height: 18)
                        .shadow(color: .black.opacity(0.20), radius: 3, x: 0, y: 1)
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .offset(x: 4, y: -4)
        }
    }

    // MARK: - Position management

    private func loadInitialPosition(screenSize: CGSize) {
        if hasSavedPosition {
            // 恢复上次保存的位置（相对于屏幕中心的偏移）
            position = CGSize(width: savedX, height: savedY)
        } else {
            // 默认位置：保证整个 HStack（气泡 200 + 图标 44 = 244pt）
            // 的右边沿距屏幕右边 trailingMargin pt，不会被裁掉。
            //
            // .position() 使用 HStack 的几何中心：
            //   centerX_on_screen = geo.width/2 + position.width
            // 想让右边沿落在 `screenWidth - trailingMargin`，
            //   targetCenterX = screenWidth - trailingMargin - hstackWidth/2
            //   ⇒ position.width = screenWidth/2 - trailingMargin - hstackWidth/2
            let bubbleMaxWidth: CGFloat = 200
            let hstackWidth: CGFloat = bubbleMaxWidth + iconSize   // 244
            let trailingMargin: CGFloat = 24
            let bottomMargin: CGFloat = 200    // 避免与底部 Rescan 按钮（bottom 130）重叠

            let offsetX = screenSize.width / 2 - trailingMargin - hstackWidth / 2
            let offsetY = screenSize.height / 2 - bottomMargin
            position = CGSize(width: offsetX, height: offsetY)
        }
    }

    private func savePosition() {
        savedX = position.width
        savedY = position.height
        hasSavedPosition = true
    }

    // MARK: - Animations

    private func expand() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
            bubbleScale   = 1.0
            bubbleOpacity = 1.0
        }
    }

    private func collapse() {
        // 关闭前保存最终位置
        savePosition()

        // 1. 先播放关闭动画，让用户看到收起效果
        withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
            bubbleScale   = 0.0
            bubbleOpacity = 0.0
        }

        // 2. 动画完成后再通知外部 dismiss（外部会把 showFunFact 置 false，移除本视图）
        //    并设置内部 isCollapsed 状态。延时与 spring response 对齐。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.44) {
            isCollapsed = true
            // 不显示内部呼吸灯，因为外部 LogoFrame 已经有了
            onDismiss?()
        }
    }
}

// MARK: - Right-pointing tail

private struct RightTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.closeSubpath()
        }
    }
}

// MARK: - FunFactBreathingGlow (shared)

struct FunFactBreathingGlow: View {
    let radius: CGFloat
    @State private var pulse = false

    // 品牌三色（与 LogoFrame 的 stroke 一致）
    private let glowColors: [Color] = [
        Color(red: 0x69/255.0, green: 0xAC/255.0, blue: 0x14/255.0),
        Color(red: 0x49/255.0, green: 0x3D/255.0, blue: 0x89/255.0),
        Color(red: 0xF8/255.0, green: 0x4C/255.0, blue: 0x4C/255.0),
    ]

    var body: some View {
        let baseDiameter = radius * 2

        ZStack {
            // ── 1) 柔和外发光：大尺寸径向渐变 + 模糊，营造"被点亮"的氛围 ─
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color(red: 0xFF/255.0, green: 0xC8/255.0, blue: 0x8A/255.0).opacity(0.35),
                            Color.white.opacity(0.0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: baseDiameter * 0.95
                    )
                )
                .frame(width: baseDiameter * 2.2, height: baseDiameter * 2.2)
                .blur(radius: 14)
                .opacity(pulse ? 0.95 : 0.55)
                .scaleEffect(pulse ? 1.06 : 0.94)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)

            // ── 2) 品牌色角向光晕：缓慢旋转 + 模糊，色彩流动感 ─────────
            Circle()
                .fill(
                    AngularGradient(
                        colors: glowColors + [glowColors[0]],
                        center: .center
                    )
                )
                .frame(width: baseDiameter * 1.55, height: baseDiameter * 1.55)
                .blur(radius: 18)
                .opacity(pulse ? 0.55 : 0.30)
                .scaleEffect(pulse ? 1.10 : 0.96)
                .rotationEffect(.degrees(pulse ? 360 : 0))
                .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: pulse)

            // ── 3) 两道向外扩散的细描边脉冲（不再有黑色实心填充） ─────
            ForEach(0..<2, id: \.self) { i in
                let size = baseDiameter + CGFloat(i + 1) * 12
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: glowColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: size, height: size)
                    .opacity(pulse ? 0.0 : 0.45 - Double(i) * 0.18)
                    .scaleEffect(pulse ? 1.45 : 1.0)
                    .animation(
                        .easeOut(duration: 1.8)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.45),
                        value: pulse
                    )
            }
        }
        .compositingGroup()
        .allowsHitTesting(false)
        .onAppear { pulse = true }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.6).ignoresSafeArea()
        FunFactBubble(
            text: "Fun fact ✨",
            feedbackText: "Your eyebrow raise is 78% — you look expressive today!",
            onDismiss: {}
        )
    }
}

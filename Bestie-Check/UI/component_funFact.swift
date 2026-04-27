//
//  component_funFact.swift
//  Bestie-Check
//
//  Created by in4matx_inst on 4/27/26.
//


import SwiftUI

// MARK: - FunFactBubble

/// 布局：[气泡 →尾巴][LaunchIcon SVG（无背景）]
/// 接口：
///   text        — 主标题文字（必填）
///   feedbackText — 副文本 / AI feedback（可选，nil 时不显示）
///   url         — 点击气泡打开的网页链接（可选，nil 时不跳转）
///   onDismiss   — 关闭回调
struct FunFactBubble: View {
    let text: String
    var feedbackText: String? = nil
    var url: URL?             = nil
    var onDismiss: (() -> Void)? = nil

    @State private var isCollapsed:   Bool    = false
    @State private var bubbleScale:   CGFloat = 0.0
    @State private var bubbleOpacity: Double  = 0.0
    @State private var glowOpacity:   Double  = 0.0
    @State private var position:      CGSize  = .zero
    @GestureState private var dragDelta: CGSize = .zero

    private let iconSize: CGFloat = 44

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            if !isCollapsed {
                bubbleContent
                    .scaleEffect(bubbleScale, anchor: .trailing)
                    .opacity(bubbleOpacity)
                    .transition(.identity)
            }
            iconView
        }
        .offset(x: position.width + dragDelta.width,
                y: position.height + dragDelta.height)
        .gesture(
            DragGesture()
                .updating($dragDelta) { v, state, _ in state = v.translation }
                .onEnded { v in
                    position.width  += v.translation.width
                    position.height += v.translation.height
                }
        )
        .onAppear { expand() }
    }

    // MARK: - Bubble

    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header row: title + close button ──────────────────────────
            HStack(alignment: .top, spacing: 0) {
                Text(text)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, feedbackText == nil ? 10 : 4)
                    .frame(maxWidth: 200, alignment: .leading)

                Button { collapse() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
                .padding(.top, 4)
            }

            // ── Feedback sub-text (optional) ───────────────────────────────
            if let fb = feedbackText, !fb.isEmpty {
                Text(fb)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                    .frame(maxWidth: 200, alignment: .leading)
            }

            // ── URL hint (shown when url is provided) ─────────────────────
            if url != nil {
                HStack(spacing: 4) {
                    Image(systemName: "safari")
                        .font(.system(size: 10))
                    Text("Tap to learn more")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.blue.opacity(0.8))
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
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
            guard let link = url else { return }
            UIApplication.shared.open(link)
        }
    }

    // MARK: - Icon

    private var iconView: some View {
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
    }

    // MARK: - Animations

    private func expand() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
            bubbleScale   = 1.0
            bubbleOpacity = 1.0
        }
    }

    private func collapse() {
        withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
            bubbleScale   = 0.0
            bubbleOpacity = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            isCollapsed = true
            withAnimation(.easeIn(duration: 0.25)) { glowOpacity = 1.0 }
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

// MARK: - Breathing glow (shared — used by FunFactBubble & LogoFrame)

struct FunFactBreathingGlow: View {
    let radius: CGFloat
    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0x69/255.0, green: 0xAC/255.0, blue: 0x14/255.0),
                                Color(red: 0x49/255.0, green: 0x3D/255.0, blue: 0x89/255.0),
                                Color(red: 0xF8/255.0, green: 0x4C/255.0, blue: 0x4C/255.0),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width:  (radius * 2) + CGFloat(i + 1) * 10,
                           height: (radius * 2) + CGFloat(i + 1) * 10)
                    .opacity(pulse ? 0.0 : Double(3 - i) * 0.25)
                    .scaleEffect(pulse ? 1.4 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.30),
                        value: pulse
                    )
            }
        }
        .onAppear { pulse = true }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.75).ignoresSafeArea()
        FunFactBubble(
            text: "Did you know? 👀",
            feedbackText: "Your eyebrow raise is 78% — you look naturally expressive today! ✨",
            url: URL(string: "https://example.com"),
            onDismiss: {}
        )
        .padding(32)
    }
}

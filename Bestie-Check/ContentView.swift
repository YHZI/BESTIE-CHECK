//
//  ContentView.swift
//  Bestie-Check
//
//  主界面：ARView + 气泡 overlay + 调试面板
//

import SwiftUI
import RealityKit
import Combine
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = FaceMeshAssistantViewModel()
    @ObservedObject private var faceDetectionProvider = FaceDetectionProvider.shared
    
    // 气泡框展开状态
    @State private var isBubbleExpanded: Bool = false
    
    // 测试文本模式（短文本/长文本）
    @State private var isLongTextMode: Bool = false
    
    // ViewFinder 扫描线开关
    @State private var showViewFinderScan: Bool = false
    
    // 背景模式：false = Camera, true = RGB Colors
    @State private var useRGBBackground: Bool = false
    
    /// User takes a new photo for share (not the first face frame).
    @State private var isShareCameraPresented: Bool = false
    @State private var isShareSheetPresented: Bool = false
    @State private var shareActivityItems: [Any] = []
    
    private func makeShareImage(photo: UIImage, replyText: String) -> UIImage {
        let safeReply = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = "Bestie-Check 妆容分析"
        
        // 4:5 is a good default for sharing (Instagram-friendly)
        let canvasSize = CGSize(width: 1080, height: 1350)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        
        return renderer.image { ctx in
            let bounds = CGRect(origin: .zero, size: canvasSize)
            
            // Background photo (aspect fill)
            let imageSize = photo.size
            let scale = max(canvasSize.width / max(imageSize.width, 1), canvasSize.height / max(imageSize.height, 1))
            let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let drawOrigin = CGPoint(x: (canvasSize.width - drawSize.width) / 2, y: (canvasSize.height - drawSize.height) / 2)
            photo.draw(in: CGRect(origin: drawOrigin, size: drawSize))
            
            // Bottom gradient to improve text readability
            let colors = [UIColor.black.withAlphaComponent(0.0).cgColor, UIColor.black.withAlphaComponent(0.72).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0.0, 1.0])!
            let gradientStart = CGPoint(x: canvasSize.width / 2, y: canvasSize.height * 0.45)
            let gradientEnd = CGPoint(x: canvasSize.width / 2, y: canvasSize.height)
            ctx.cgContext.drawLinearGradient(gradient, start: gradientStart, end: gradientEnd, options: [])
            
            // SLOGAN
            let sloganTop = "Find your beauty on"
            let sloganBottom = "GOSHASHA"

            // paragraph（右对齐）
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .right

            // 上面那行（小字）
            let attrTop = NSAttributedString(string: sloganTop, attributes: [
                .font: UIFont(name: "Playwrite IE", size: 36) ?? UIFont.systemFont(ofSize: 36),
                .foregroundColor: UIColor.white.withAlphaComponent(0.95),
                .paragraphStyle: paragraphStyle
            ])

            // 下面品牌名（大字）
            let attrBottom = NSAttributedString(string: sloganBottom, attributes: [
                .font: UIFont(name: "Playwrite IE", size: 64) ?? UIFont.systemFont(ofSize: 64),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ])

            // 位置（右上角）
            let rightMargin: CGFloat = 80
            let topMargin: CGFloat = 120
            let width: CGFloat = canvasSize.width - rightMargin * 2

            // 画文字
            attrTop.draw(in: CGRect(x: rightMargin, y: topMargin, width: width, height: 50))
            attrBottom.draw(in: CGRect(x: rightMargin, y: topMargin + 48, width: width, height: 80))
            
            // Text card
            let padding: CGFloat = 56
            let cardWidth = canvasSize.width - padding * 2
            let cardMaxHeight: CGFloat = canvasSize.height * 0.45
            let cardRect = CGRect(
                x: padding,
                y: canvasSize.height - padding - cardMaxHeight,
                width: cardWidth,
                height: cardMaxHeight
            )
            
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 32)
            UIColor.white.withAlphaComponent(0.10).setFill()
            cardPath.fill()
            UIColor.white.withAlphaComponent(0.18).setStroke()
            cardPath.lineWidth = 1
            cardPath.stroke()
            
            let textInset: CGFloat = 28
            let textRect = cardRect.insetBy(dx: textInset, dy: textInset)
            
            let titleFont = UIFont.systemFont(ofSize: 44, weight: .semibold)
            let bodyFont = UIFont.systemFont(ofSize: 36, weight: .regular)
            
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            paragraph.lineSpacing = 8
            
            let attributed = NSMutableAttributedString()
            attributed.append(NSAttributedString(string: title + "\n", attributes: [
                .font: titleFont,
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]))
            attributed.append(NSAttributedString(string: safeReply.isEmpty ? "（暂无回复）" : safeReply, attributes: [
                .font: bodyFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.95),
                .paragraphStyle: paragraph
            ]))
            
            // Fit text in card (truncate if too long)
            let framesetter = CTFramesetterCreateWithAttributedString(attributed)
            let maxTextSize = CGSize(width: textRect.width, height: textRect.height)
            let fitRange = CTFramesetterSuggestFrameSizeWithConstraints(
                framesetter,
                CFRange(location: 0, length: attributed.length),
                nil,
                maxTextSize,
                nil
            )
            
            // If text overflows, we truncate to fit
            let drawAttr: NSAttributedString
            if fitRange.height <= maxTextSize.height {
                drawAttr = attributed
            } else {
                // Rough truncation: binary search for a fitting prefix, then add ellipsis
                var low = 0
                var high = attributed.length
                var best = 0
                while low <= high {
                    let mid = (low + high) / 2
                    let sub = attributed.attributedSubstring(from: NSRange(location: 0, length: mid))
                    let fs = CTFramesetterCreateWithAttributedString(sub as CFAttributedString)
                    let size = CTFramesetterSuggestFrameSizeWithConstraints(fs, CFRange(location: 0, length: sub.length), nil, maxTextSize, nil)
                    if size.height <= maxTextSize.height {
                        best = mid
                        low = mid + 1
                    } else {
                        high = mid - 1
                    }
                }
                
                let prefix = NSMutableAttributedString(attributedString: attributed.attributedSubstring(from: NSRange(location: 0, length: max(best - 1, 0))))
                prefix.append(NSAttributedString(string: "…", attributes: [
                    .font: bodyFont,
                    .foregroundColor: UIColor.white.withAlphaComponent(0.95),
                    .paragraphStyle: paragraph
                ]))
                drawAttr = prefix
            }
            
            drawAttr.draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        }
    }
    
    
    // 测试文本内容
    var testText: String {
        if isLongTextMode {
            return """
This is a very long text for testing the responsive behavior of the ReactTextBar component. When the text content exceeds the default frame size, the bubble should automatically expand and extend its right edge line all the way down to near the bottom of the screen.

The bubble shape should maintain the L-shaped cutout at the top right corner throughout the expansion process. The background opacity should also change from 40% to 70% to make the expanded bubble more visible and prominent on the screen.

This text continues with even more content to ensure that the height exceeds 120 points and triggers the expansion mechanism. We need to test multiple paragraphs and line breaks to verify that the layout handles various text lengths correctly.

Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
"""
        } else {
            return viewModel.bubbleText.isEmpty ? "Hello! 😊" : viewModel.bubbleText
        }
    }
    
    var body: some View {
        ZStack {
            // AR 画面（全屏）
            ARViewContainer(viewModel: viewModel, useRGBBackground: $useRGBBackground)
                .ignoresSafeArea()
            
            // ViewFinder 取景框（全屏居中）- 展开时隐藏
            if !isBubbleExpanded {
                ViewFinder(
                    frameWidth: 280,
                    frameHeight: 360,
                    cornerLength: 30,
                    lineWidth: 3,
                    color: faceDetectionProvider.faceDetected ? .green : .white,
                    showScanLine: showViewFinderScan,
                    faceDetected: faceDetectionProvider.faceDetected
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: isBubbleExpanded)
            }
            
            // ARIcon 组件（放在 ViewFinder 下面）- 展开时隐藏
            if !isBubbleExpanded {
                VStack {
                    Spacer()
                    ARIconView(
                        pupilPosition: CGPoint(x: 0.5, y: 0.5),
                        eyeSocketColor: .white,
                        pupilColor: .white,
                        strokeWidth: 3.5,
                        showDecorations: true,
                        enableBlinking: true
                    )
                    .frame(width: 56, height: 65)  // 70% of original 80x93
                    .opacity(0.7)  // 70% opacity
                    .padding(.bottom, 65)  // 65px from bottom
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: isBubbleExpanded)
            }
            
            // AI 气泡 overlay（始终显示）
            VStack {
                ZStack(alignment: .topTrailing) {
                    // 气泡框 - 三个接口：title, text, isExpanded
                    ReactTextBarWithCircle(
                        title: "",
                        text: testText,
                        isExpanded: $isBubbleExpanded
                    )
                    .onChange(of: isLongTextMode) { oldValue, newValue in
                        print("🔀 ContentView: isLongTextMode changed: \(oldValue) → \(newValue)")
                        print("📏 ContentView: testText length is now: \(testText.count)")
                        print("📖 ContentView: First 100 chars: \(String(testText.prefix(100)))")
                    }
                    
                    // LogoFrame 圆形叠加在气泡上
                    LogoFrame(
                        horizontalOffset: -6,   // 调整水平位置：正值向右，负值向左
                        verticalOffset: 0,     // 调整垂直位置：正值向下，负值向上
                        imageScale: 1.2        // 调整图像缩放：1.0为原始大小
                    )
                        .frame(height: 120)  // 与气泡高度一致
                    
                    // Share（右上角）：先打开相机拍照，再合成分享图
                    Button {
                        isShareCameraPresented = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black.opacity(0.75))
                            .padding(10)
                            .background(Color.white.opacity(0.85))
                            .clipShape(Circle())
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 12)
                    .disabled(viewModel.bubbleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.top, 60)
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .zIndex(1)  // 固定 zIndex，不再动态提升
            .fullScreenCover(isPresented: $isShareCameraPresented) {
                ShareCameraPicker { image in
                    isShareCameraPresented = false
                    let reply = viewModel.bubbleText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let image, !reply.isEmpty else { return }
                    shareActivityItems = [makeShareImage(photo: image, replyText: reply)]
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        isShareSheetPresented = true
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $isShareSheetPresented, onDismiss: {
                shareActivityItems = []
            }) {
                ShareSheet(activityItems: shareActivityItems)
            }
            
            // 左上角返回按钮（智能模式：自动处理 ReactTextBar 状态）
            VStack {
                HStack {
                    BackButton(
                        diameter: 22,
                        isTextBarExpanded: Binding(
                            get: { isBubbleExpanded ? true : nil },
                            set: { newValue in
                                if let value = newValue {
                                    isBubbleExpanded = value
                                } else {
                                    isBubbleExpanded = false
                                }
                            }
                        ),
                        onResetDetection: {
                            // 重置 APP 后台检测方法
                            print("🔄 Resetting backend detection...")
                            viewModel.resetDetection()
                        },
                        isLongTextMode: Binding(
                            get: { isLongTextMode ? true : nil },
                            set: { newValue in
                                if let value = newValue {
                                    isLongTextMode = value
                                } else {
                                    isLongTextMode = false
                                }
                            }
                        ),
                        action: {
                            // 额外的自定义操作（可选）
                            print("📍 Back button custom action executed")
                        }
                    )
                    .padding(.leading, 40)
                    .padding(.top, 24)
                    
                    Spacer()
                }
                Spacer()
            }
            .zIndex(100)  // 在气泡之上，调试面板之下
            
            // 调试面板（右上角）- 始终在最前端
            HStack {
                Spacer()
                DebugPanelView(
                    viewModel: viewModel,
                    isLongTextMode: $isLongTextMode,
                    showViewFinderScan: $showViewFinderScan,
                    useRGBBackground: $useRGBBackground
                )
            }
            .zIndex(1000)  // 始终在最前端
            
            // Loading 指示器
            if viewModel.isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Analyzing...")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
                .padding(16)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
                .padding(.bottom, 100)
            }
            
            // 错误提示
            if let errorMessage = viewModel.errorMessage {
                VStack {
                    Spacer()
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                        .padding(.bottom, 200)
                        .onTapGesture {
                            viewModel.errorMessage = nil
                        }
                }
            }
        }
        .onAppear {
            // ViewModel 初始化时已启动处理
        }
        .onDisappear {
            viewModel.stopARSession()
        }
    }
}

#Preview {
    ContentView()
}

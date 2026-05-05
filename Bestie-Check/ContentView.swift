//
//  ContentView.swift
//  Bestie-Check
//
//  主界面：ARView + 气泡 overlay + 调试面板
//

import SwiftUI
import RealityKit
import Combine

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
    
    /// Share 流程打开时冻结的文案与图（避免 preview 随 ViewModel 后台刷新而跳动）
    @State private var shareFrozenReplyText: String = ""
    @State private var shareFrozenPreImage: UIImage? = nil

    /// FunFact 自动弹出定时器
    @State private var funFactTimer: DispatchWorkItem? = nil
    /// 标记当前分析会话是否已显示过 FunFact（避免反复触发）
    @State private var funFactShownInCurrentSession: Bool = false

    var onAppReady: (() -> Void)? = nil

    
    // 测试文本内容
    var testText: String {
        if isLongTextMode {
            return """
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
                    // 气泡框 - 三个接口：title, text, isExpanded, shouldExpand
                    ReactTextBarWithCircle(
                        title: "Bestie Check",  // ← 硬编码标题
                        text: testText,
                        isExpanded: $isBubbleExpanded,
                        shouldExpand: $viewModel.shouldExpandBubble,
                        shareEnabled: !viewModel.bubbleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        onShareTapped: {
                            // 分享图片使用纯 summary 文本（不含标题和格式）
                            shareFrozenReplyText = viewModel.bubbleTextForShare.isEmpty ? testText : viewModel.bubbleTextForShare
                            shareFrozenPreImage = viewModel.lastSharedImage
                            isShareCameraPresented = true
                        }
                    )
                    .onChange(of: isLongTextMode) { oldValue, newValue in
                        print("🔀 ContentView: isLongTextMode changed: \(oldValue) → \(newValue)")
                        print("📏 ContentView: testText length is now: \(testText.count)")
                        print("📖 ContentView: First 100 chars: \(String(testText.prefix(100)))")
                    }
                    
                    // LogoFrame 圆形叠加在气泡上
                    LogoFrame(
                        horizontalOffset: -6,
                        verticalOffset: 0,
                        imageScale: 1.2,
                        isGlowing: viewModel.logoGlowing,
                        onTap: {
                            // 点击 Logo 时的逻辑
                            if viewModel.showFunFact {
                                // 如果 FunFact 已经显示，关闭它
                                viewModel.showFunFact = false
                                viewModel.logoGlowing = true  // 显示呼吸灯
                            } else {
                                // 如果 FunFact 未显示，打开它
                                viewModel.logoGlowing = false  // 关闭呼吸灯
                                viewModel.showFunFact = true
                            }
                        }
                    )
                        .frame(height: 120)
                }
                .padding(.top, 60)
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .zIndex(1)  // 固定 zIndex，不再动态提升
            .shareFlow(isPresented: $isShareCameraPresented, isBubbleExpanded: $isBubbleExpanded, replyText: shareFrozenReplyText, preCapturedImage: shareFrozenPreImage, viewModel: viewModel)
            .onChange(of: isShareCameraPresented) { oldValue, sharing in
                // 分享流程打开时暂停 ARSession，避免与 CameraPreview 争抢前置摄像头
                if sharing {
                    print("📷 Share flow opened - pausing AR session")
                    viewModel.pauseARSession()
                    // 打开分享流程时自动收起 FunFact
                    if viewModel.showFunFact {
                        viewModel.showFunFact = false
                    }
                } else if oldValue == true {
                    // 只在从 true 变为 false 时恢复（避免初始化时意外调用）
                    print("📷 Share flow closed - resuming AR session")
                    // 短暂延迟恢复，确保 Share UI 完全关闭
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05秒
                        viewModel.resumeARSession()
                    }
                }
            }
            .onChange(of: isBubbleExpanded) { _, expanded in
                // ReactTextBar 展开状态变化时的处理
                if expanded {
                    // 气泡展开 → 启动 2 秒定时器，自动弹出 FunFact（但只在未手动显示过的情况下）
                    guard !funFactShownInCurrentSession else {
                        print("⏭️ FunFact already shown in this session, skipping auto-trigger")
                        return
                    }
                    
                    funFactTimer?.cancel()  // 取消之前的定时器（如果有）
                    let task = DispatchWorkItem { [self] in
                        guard !viewModel.showFunFact else { return }  // 如果已经显示，跳过
                        guard !funFactShownInCurrentSession else { return }  // 二次检查
                        print("⏰ Timer triggered - showing FunFact")
                        viewModel.showFunFact = true
                        viewModel.logoGlowing = false  // 关闭 logo 呼吸灯
                        funFactShownInCurrentSession = true  // 标记已显示
                    }
                    funFactTimer = task
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
                } else {
                    // 气泡收起 → 取消定时器
                    print("📦 ReactTextBar collapsed - canceling timer")
                    funFactTimer?.cancel()
                    funFactTimer = nil
                }
            }
            .onChange(of: viewModel.showFunFact) { _, showing in
                // 监听 FunFact 显示状态变化，同步 logoGlowing
                if showing {
                    // FunFact 被显示 → 关闭呼吸灯
                    funFactShownInCurrentSession = true
                    viewModel.logoGlowing = false
                    print("✨ FunFact shown - marking session and disabling glow")
                }
            }
            .onChange(of: viewModel.logoGlowing) { _, glowing in
                // 监听 logoGlowing 变化，确保与 showFunFact 同步
                if glowing && viewModel.showFunFact {
                    // 如果呼吸灯亮起但 FunFact 还在显示，这是不一致状态，修正它
                    print("⚠️ Inconsistent state detected: logoGlowing=true but showFunFact=true, fixing...")
                    viewModel.logoGlowing = false
                }
            }
            .onChange(of: viewModel.bubbleText) { oldText, newText in
                // 当 bubbleText 变化时（新的分析结果或重置），重置 FunFact 会话标记
                if newText.isEmpty && !oldText.isEmpty {
                    // 从有内容变为空（resetToWelcome）
                    print("🔄 bubbleText cleared - resetting FunFact session")
                    funFactShownInCurrentSession = false
                    funFactTimer?.cancel()
                    funFactTimer = nil
                }
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
                            // 重置 FunFact 会话标记，允许下次触发
                            funFactShownInCurrentSession = false
                            funFactTimer?.cancel()
                            funFactTimer = nil
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
                    useRGBBackground: $useRGBBackground,
                    showFunFact: $viewModel.showFunFact
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

            // ── FunFact floating bubble (draggable overlay) ──────────────
            if viewModel.showFunFact {
                FunFactBubble(
                    text: "Fun Fact ✨",                          // ← 硬编码主标题
                    feedbackText: viewModel.funFactText.isEmpty ? nil : viewModel.funFactText,
                    //            ↑ 使用 funFactText（锁定机制，不会持续刷新）
                    url: URL(string: "https://www.google.com"), // TODO: replace with real URL
                    onDismiss: {
                        viewModel.showFunFact = false
                        // FunFact 关闭后显示呼吸灯，让用户知道可以再次点击
                        withAnimation(.easeIn(duration: 0.2)) {
                            viewModel.logoGlowing = true
                        }
                    }
                )
                // FunFactBubble uses its own GeometryReader for positioning
                // Do NOT add padding/frame here — it shrinks the geo and breaks default position
                .ignoresSafeArea()
                .allowsHitTesting(true)
                .zIndex(10)
            }
        }
        .overlay(alignment: .bottom) {
            // 首次自动扫描完成后显示，用于手动触发下一次分析（与 ViewModel.requestReanalysis 配对）
            if viewModel.hasCompletedFirstAnalysis {
                Button {
                    viewModel.requestReanalysis()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Rescan")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity((viewModel.canRequestReanalysis && !viewModel.isLoading) ? 0.55 : 0.35))
                    )
                }
                .disabled(!viewModel.canRequestReanalysis || viewModel.isLoading)
                .padding(.bottom, 130)
                .accessibilityLabel("Rescan face analysis")
            }
        }
        .onAppear {
            // ViewModel 初始化时已启动处理
            onAppReady?()
        }
        .onDisappear {
            viewModel.stopARSession()
        }
    }
    
    init(viewModel: FaceMeshAssistantViewModel? = nil, onAppReady: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: viewModel ?? FaceMeshAssistantViewModel())
        self.onAppReady = onAppReady
    }
}

#Preview {
    ContentView()
}
